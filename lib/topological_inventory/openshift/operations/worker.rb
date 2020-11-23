require "manageiq-messaging"
require "topological_inventory/openshift/logging"
require "topological_inventory/openshift/messaging_client"
require "topological_inventory/openshift/operations/processor"
require "topological_inventory/providers/common/operations/health_check"

module TopologicalInventory
  module Openshift
    module Operations
      class Worker
        include Logging

        def initialize(metrics)
          self.metrics = metrics
        end

        def run
          logger.info("Topological Inventory Openshift Operations worker started...")

          client.subscribe_topic(queue_opts) do |message|
            process_message(message)
            client.ack(message.ack_ref)
            TopologicalInventory::Providers::Common::Operations::HealthCheck.touch_file
          end
        ensure
          client&.close
        end

        private

        attr_accessor :metrics

        def client
          @client ||= TopologicalInventory::Openshift::MessagingClient.default.worker_listener
        end

        def queue_opts
          TopologicalInventory::Openshift::MessagingClient.default.worker_listener_queue_opts
        end

        def process_message(message)
          model, method = message.message.split(".")

          processor = Processor.new(model, method, message.payload, metrics)
          processor.process
        rescue => err
          metrics.record_error
          logger.error("#{err}\n#{err.backtrace.join("\n")}")
        end
      end
    end
  end
end
