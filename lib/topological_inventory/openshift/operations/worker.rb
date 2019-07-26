require "manageiq-messaging"
require "sources-api-client"
require "topological_inventory/openshift/logging"
require "topological_inventory/openshift/operations/processor"
require "topological_inventory-api-client"

module TopologicalInventory
  module Openshift
    module Operations
      class Worker
        include Logging

        def initialize(metrics, messaging_client_opts = {})
          self.metrics               = metrics
          self.messaging_client_opts = default_messaging_opts.merge(messaging_client_opts)
        end

        def run
          # Open a connection to the messaging service
          client = ManageIQ::Messaging::Client.open(messaging_client_opts)

          logger.info("Topological Inventory Openshift Operations worker started...")

          client.subscribe_topic(queue_opts) do |message|
            process_message(message)
            client.ack(message.ack_ref)
          end
        ensure
          client&.close
        end

        private

        attr_accessor :messaging_client_opts, :metrics

        def process_message(message)
          model, method = (message.message || message.headers["message_type"]).split(".")

          processor = Processor.new(model, method, message.payload, metrics)
          processor.process
        rescue => err
          metrics.record_error
          logger.error("#{err}\n#{err.backtrace.join("\n")}")
        end

        def queue_name
          "platform.topological-inventory.operations-openshift"
        end

        def queue_opts
          {
            :auto_ack    => false,
            :max_bytes   => 50_000,
            :service     => queue_name,
            :persist_ref => "topological-inventory-operations-openshift"
          }
        end

        def default_messaging_opts
          {
            :protocol   => :Kafka,
            :client_ref => "topological-inventory-operations-openshift",
            :group_ref  => "topological-inventory-operations-openshift"
          }
        end
      end
    end
  end
end
