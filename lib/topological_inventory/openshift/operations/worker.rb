require "manageiq-messaging"
require "topological_inventory/openshift/logging"
require "topological_inventory/openshift/messaging_client"
require "topological_inventory/openshift/operations/processor"
require "topological_inventory/providers/common/mixins/statuses"
require "topological_inventory/providers/common/operations/health_check"

module TopologicalInventory
  module Openshift
    module Operations
      class Worker
        include Logging
        include TopologicalInventory::Providers::Common::Mixins::Statuses

        def initialize(metrics)
          self.metrics = metrics
        end

        def run
          logger.info("[STDERR-INFO] Topological Inventory Openshift Operations worker started...")
          logger.warn("[STDERR-WARN] Topological Inventory Openshift Operations worker started...")
          logger.debug("[STDERR-DEBUG] Topological Inventory Openshift Operations worker started...")
          logger.error("[STDERR-ERROR] Topological Inventory Openshift Operations worker started...")

          raise StandardError, "This is standard and simulated error."
        rescue => e
          logger.error("#{e}\n#{e.backtrace.join("\n")}")
        ensure
          original_run
        end

        def original_run
          client.subscribe_topic(queue_opts) do |message|
            process_message(message)
          end
        rescue => e
          logger.error("#{e}\n#{e.backtrace.join("\n")}")
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
          result = Processor.process!(message, metrics)
          metrics&.record_operation(message.message, :status => result)
        rescue => e
          logger.error("#{e}\n#{e.backtrace.join("\n")}")
          metrics&.record_operation(message.message, :status => operation_status[:error])
        ensure
          message.ack
          TopologicalInventory::Providers::Common::Operations::HealthCheck.touch_file
        end
      end
    end
  end
end
