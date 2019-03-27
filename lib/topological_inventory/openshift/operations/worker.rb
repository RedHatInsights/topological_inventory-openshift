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
          self.sleep_poll            = 10   # seconds
          self.poll_timeout          = 1800 # seconds
        end

        def run
          # Open a connection to the messaging service
          self.client = ManageIQ::Messaging::Client.open(messaging_client_opts)

          logger.info("Topological Inventory Openshift Operations worker started...")

          client.subscribe_messages(queue_opts) do |messages|
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

        attr_accessor :messaging_client_opts, :client, :api_client, :sleep_poll, :poll_timeout

        def process_message(client, msg)
          logger.info("Processing #{msg.message} with msg: #{msg.payload}")
          # TODO: Move to separate module later when more message types are expected aside from just ordering
          order_service(client, msg)
        rescue StandardError => e
          logger.error(e.message)
          logger.error(e.backtrace.join("\n"))
          nil
        end

        def order_service(client, msg)
          task_id, service_plan_id, order_params = msg.payload.values_at("task_id", "service_plan_id", "order_params")

          service_plan     = api_client.show_service_plan(service_plan_id)
          service_offering = api_client.show_service_offering(service_plan.service_offering_id)
          source_id        = service_plan.source_id

          catalog_client = Core::ServiceCatalogClient.new(source_id)

          logger.info("Ordering #{service_offering.name} #{service_plan.name}...")
          service_instance = catalog_client.order_service_plan(
            service_plan.name, service_offering.name, order_params
          )
          client.ack(msg.ack_ref)
          poll_order_complete(task_id, source_id, service_instance, service_offering, service_plan)
          logger.info("Ordering #{service_offering.name} #{service_plan.name}...Complete")
        rescue StandardError => err
          logger.error("Exception while ordering #{err}")
          logger.error(err.backtrace.join("\n"))
          update_task(task_id, :state => "completed", :status => "error", :context => {:error => err.to_s})
        end

        def update_task(task_id, state:, status:, context:)
          task = TopologicalInventoryApiClient::Task.new("state" => state, "status" => status, "context" => context.to_json)
          api_client.update_task(task_id, task)
        end

        def poll_order_complete(task_id, source_id, service_instance, service_offering, service_plan)
          catalog_client = Core::ServiceCatalogClient.new(source_id)
          catalog_client.wait_for_provision_complete(service_instance)

          context = svc_instance_context_with_url(source_id, service_instance)
          status  = provisioning_status(service_instance)

          update_task(task_id, :state => "completed", :status => status, :context => context)
        end

        def svc_instance_context_with_url(source_id, service_instance)
          context = {
            :service_instance => {
              :source_id  => source_id,
              :source_ref => service_instance.spec&.externalID
            }
          }

          if provisioning_status(service_instance) == "ok"
            url = svc_instance_url(source_id, service_instance)
            context[:service_instance][:url] = url if url.present?
          end

          context
        end

        def svc_instance_url(source_id, service_instance)
          svc_instance = svc_instance_by_source_ref(source_id, service_instance.spec&.externalID)
          return if svc_instance.nil?

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

          header_params = { 'Accept' => api.select_header_accept(['application/json']) }
          query_params = { :'source_id' => source_id, :'source_ref' => source_ref }

          count = 0
          timeout_count = poll_timeout / sleep_poll

          service_instance = nil
          loop do
            data, status_code, headers = api.call_api(:GET, "/service_instances",
                                                      :header_params => header_params,
                                                      :query_params  => query_params,
                                                      :form_params   => {},
                                                      :body          => nil,
                                                      :auth_names    => ['UserSecurity'],
                                                      :return_type   => 'ServiceInstancesCollection')

            service_instance = data.data&.first if data.meta.count > 0
            break if service_instance.present?

            break if (count += 1) >= timeout_count
            sleep(sleep_poll)
          end

          if service_instance.nil?
            logger.error("Failed to find service_instance by source_id [#{source_id}] source_ref [#{source_ref}]")
          end

          service_instance
        end

        def queue_opts
          {
            :auto_ack  => false,
            :max_bytes => 50_000,
            :service   => "platform.topological-inventory.operations-openshift"
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
