require "topological_inventory/openshift/logging"
require "topological_inventory/openshift/operations/core/service_catalog_client"

module TopologicalInventory
  module Openshift
    module Operations
      class Processor
        include Logging

        def initialize(model, method, payload)
          self.model   = model
          self.method  = method
          self.payload = payload
        end

        def process
          logger.info("Processing #{model}##{method} [#{payload}]...")
          order_service(payload)
          logger.info("Processing #{model}##{method} [#{payload}]...Complete")
        end

        private

        attr_accessor :model, :method, :payload

        def order_service(payload)
          task_id, service_plan_id, order_params = payload.values_at("task_id", "service_plan_id", "order_params")

          service_plan     = api_client.show_service_plan(service_plan_id)
          service_offering = api_client.show_service_offering(service_plan.service_offering_id)
          source_id        = service_plan.source_id

          catalog_client = Core::ServiceCatalogClient.new(source_id, payload["identity"])

          logger.info("Ordering #{service_offering.name} #{service_plan.name}...")
          service_instance = catalog_client.order_service_plan(
            service_plan.name, service_offering.name, order_params
          )
          logger.info("Ordering #{service_offering.name} #{service_plan.name}...Complete")

          poll_order_complete_thread(task_id, source_id, service_instance)
        rescue StandardError => err
          logger.error("Exception while ordering #{err}")
          logger.error(err.backtrace.join("\n"))
          update_task(task_id, :state => "completed", :status => "error", :context => {:error => err.to_s})
        end

        def update_task(task_id, state:, status:, context:)
          task = TopologicalInventoryApiClient::Task.new("state" => state, "status" => status, "context" => context.to_json)
          api_client.update_task(task_id, task)
        end

        def poll_order_complete_thread(task_id, source_id, service_instance)
          service_instance_name      = service_instance.metadata.name
          service_instance_namespace = service_instance.metadata.namespace

          Thread.new { poll_order_complete(task_id, source_id, service_instance_name, service_instance_namespace) }
        end

        def poll_order_complete(task_id, source_id, service_instance_name, service_instance_namespace)
          logger.info("Waiting for service [#{service_instance_name}] to provision...")
          catalog_client = Core::ServiceCatalogClient.new(source_id)
          service_instance = catalog_client.wait_for_provision_complete(
            service_instance_name, service_instance_namespace
          )
          logger.info("Waiting for service [#{service_instance_name}] to provision...Complete")

          context = svc_instance_context_with_url(source_id, service_instance)
          status  = provisioning_status(service_instance)

          update_task(task_id, :state => "completed", :status => status, :context => context)
        rescue StandardError => err
          logger.error("Exception while ordering #{err}")
          logger.error(err.backtrace.join("\n"))
          update_task(task_id, :state => "completed", :status => "error", :context => {:error => err.to_s})
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
          sleep_poll   = 10
          poll_timeout = 1800

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

        def api_client
          @api_client ||=
            begin
              api_client = TopologicalInventoryApiClient::ApiClient.new
              api_client.default_headers.merge!(payload["identity"]) if payload["identity"].present?
              TopologicalInventoryApiClient::DefaultApi.new(api_client)
            end
        end
      end
    end
  end
end
