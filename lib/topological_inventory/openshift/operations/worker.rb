require "manageiq-messaging"
require "topological_inventory/openshift/logging"
require "topological_inventory/openshift/operations/processor"
require "topological_inventory-api-client"

module TopologicalInventory
  module Openshift
    module Operations
      class Worker
        include Logging

        def initialize(messaging_client_opts = {})
          self.messaging_client_opts = default_messaging_opts.merge(messaging_client_opts)
        end

        def run
          # Open a connection to the messaging service
          client = ManageIQ::Messaging::Client.open(messaging_client_opts)

          logger.info("Topological Inventory Openshift Operations worker started...")

          client.subscribe_messages(queue_opts) do |messages|
            messages.each do |message|
              process_message(message)
              client.ack(message.ack_ref)
            end
          end
        ensure
          client&.close
        end

        private

        attr_accessor :messaging_client_opts

        def process_message(message)
          model, method = message.message.split(".")

          processor = Processor.new(model, method, message.payload)
          processor.process
        rescue => err
          logger.error(err)
          logger.error(err.backtrace.join("\n"))
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
