require "manageiq-messaging"
require "topological_inventory/openshift/logging"
require "topological_inventory/openshift/operations/processor"

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
          self.client = ManageIQ::Messaging::Client.open(messaging_client_opts)

          logger.info("Topological Inventory Openshift Operations worker started...")

          client.subscribe_messages(queue_opts.merge(:max_bytes => 500000)) do |messages|
            messages.each { |msg| process_message(client, msg) }
          end
        ensure
          client&.close
        end

        private

        attr_accessor :messaging_client_opts, :client, :sleep_poll, :poll_timeout

        def process_message(client, msg)
          client.ack(msg.ack_ref)
          model, method = msg.message.split(".")
          processor = Processor.new(model, method, msg.payload)
          processor.process
        rescue StandardError => e
          logger.error(e.message)
          logger.error(e.backtrace.join("\n"))
          nil
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
