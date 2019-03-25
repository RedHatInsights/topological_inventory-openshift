require "manageiq-messaging"
require "topological_inventory/openshift/logging"
require "topological_inventory/openshift/operations/core/service_catalog_client"
require "topological_inventory-api-client"

module TopologicalInventory
  module Openshift
    module Operations
      class Worker
        include Logging

        def initialize(messaging_client_opts = {})
          self.api_client            = TopologicalInventoryApiClient::DefaultApi.new
          self.messaging_client_opts = default_messaging_opts.merge(messaging_client_opts)
          self.sleep_poll            = 10
        end

        def run
          # Open a connection to the messaging service
          self.client = ManageIQ::Messaging::Client.open(messaging_client_opts)

          logger.info("Topological Inventory Openshift Operations worker started...")

          client.subscribe_messages(queue_opts.merge(:max_bytes => 500000)) do |messages|
            messages.each { |msg| process_message(client, msg) }
          end
        ensure
          client&.close
        end

        def stop
          client&.close
          self.client = nil
        end

        private

        attr_accessor :messaging_client_opts, :client, :api_client, :sleep_poll

        def process_message(_client, msg)
          logger.info("Processing #{msg.message} with msg: #{msg.payload}")
          # TODO: Move to separate module later when more message types are expected aside from just ordering
          order_service(msg.payload)
        rescue StandardError => e
          logger.error(e.message)
          logger.error(e.backtrace.join("\n"))
          nil
        end

        def order_service(payload)
          task_id, service_plan_id, order_params = payload.values_at("task_id", "service_plan_id", "order_params")

          service_plan     = api_client.show_service_plan(service_plan_id)
          service_offering = api_client.show_service_offering(service_plan.service_offering_id)

          catalog_client = Core::ServiceCatalogClient.new(service_plan.source_id)

          logger.info("Ordering #{service_offering.name} #{service_plan.name}...")
          service_instance = catalog_client.order_service_plan(
            service_plan.name, service_offering.name, order_params
          )
          logger.info("Ordering #{service_offering.name} #{service_plan.name}...Complete")

          context = svc_instance_context_with_url(service_offering, service_plan, service_instance )
          status  = provisioning_status(service_instance)

          update_task(task_id, :state => "completed", :status => status, :context => context)
        rescue StandardError => err
          logger.error("Exception while ordering #{err}")
          logger.error(err.backtrace.join("\n"))
          update_task(task_id, :state => "completed", :status => "error", :context => {:error => err.to_s})
        end

        def update_task(task_id, state:, status:, context:)
          task = TopologicalInventoryApiClient::Task.new("state" => state, "status" => status, "context" => context.to_json)
          api_client.update_task(task_id, task)
        end

        def svc_instance_context_with_url(service_offering, service_plan, service_instance)
          context = {
            :service_instance => {
              :source_id  => service_plan.source_id,
              :source_ref => service_instance.spec&.externalID
            }
          }

          if provisioning_status(service_instance) == "ok"
            context[:service_instance][:url] = svc_instance_url(service_offering, service_instance)
          end

          context
        end

        def svc_instance_url(service_offering, service_instance)
          svc_instance = svc_instance_by_source_ref(service_offering.source_id,
                                                    service_instance.spec&.externalID)

          rest_api_path = '/service_instances/{id}'.sub('{' + 'id' + '}', svc_instance&.id.to_s)
          api_client.api_client.build_request(:GET, rest_api_path).url
        end

        def provisioning_status(service_instance)
          reason = service_instance.status.conditions.first&.reason
          reason == "ProvisionedSuccessfully" ? "ok" : "error"
        end

        # Current API client doesn't support source_id and source_ref filtering
        # This is modified version of api_client.list_service_instances
        def svc_instance_by_source_ref(source_id, source_ref)
          api = api_client.api_client

          if api.config.debugging
            api.config.logger.debug('Calling API: service_instances(by source_ref)...')
          end

          header_params = { 'Accept' => api.select_header_accept(['application/json']) }
          query_params = { :'source_id' => source_id, :'source_ref' => source_ref }

          data, status_code, headers = nil, nil, nil
          loop do
            data, status_code, headers = api.call_api(:GET, "/service_instances",
                                                      :header_params => header_params,
                                                      :query_params  => query_params,
                                                      :form_params   => {},
                                                      :body          => nil,
                                                      :auth_names    => ['UserSecurity'],
                                                      :return_type   => 'ServiceInstancesCollection')

            break if data.meta.count > 0

            sleep(sleep_poll)
          end

          if api.config.debugging
            api.config.logger.debug("API called: service_instances(by source_ref)\nData: #{data.inspect}\nStatus code: #{status_code}\nHeaders: #{headers}")
          end

          data.data&.first
        end

        def queue_opts
          {
            :service => "platform.topological-inventory.operations-openshift"
          }
        end

        def default_messaging_opts
          {
            :protocol   => :Kafka,
            :client_ref => "openshift-operations-worker",
            :group_ref  => "openshift-operations-worker"
          }
        end
      end
    end
  end
end
