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

        attr_accessor :messaging_client_opts, :client, :api_client

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

          context = {
            :service_instance => {
              :source_id  => service_plan.source_id,
              :source_ref => service_instance.metadata&.uid
            }
          }

          reason = service_instance.status.conditions.first&.reason
          status = reason == "ProvisionedSuccessfully" ? "ok" : "error"

          update_task(task_id, :state => "completed", :status => status, :context => context)
        rescue StandardError => err
          update_task(task_id, :state => "completed", :status => "error", :context => {:error => err.to_s})
        end

        def update_task(task_id, state:, status:, context:)
          task = TopologicalInventoryApiClient::Task.new("state" => state, "status" => status, "context" => context.to_json)
          api_client.update_task(task_id, task)
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
