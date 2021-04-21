require "manageiq-messaging"
require "topological_inventory/providers/common/messaging_client"
require "topological_inventory/providers/common/clowder_config"

module TopologicalInventory
  module Openshift
    class MessagingClient < TopologicalInventory::Providers::Common::MessagingClient
      OPERATIONS_QUEUE_NAME = "platform.topological-inventory.operations-openshift".freeze

      # Instance of messaging client for Worker
      def worker_listener
        @worker_listener ||= ManageIQ::Messaging::Client.open(worker_listener_opts)
      end

      def worker_listener_queue_opts
        {
          :auto_ack    => false,
          :max_bytes   => 50_000,
          :service     => TopologicalInventory::Providers::Common::ClowderConfig.kafka_topic(OPERATIONS_QUEUE_NAME),
          :persist_ref => "topological-inventory-operations-openshift"
        }
      end

      private

      def worker_listener_opts
        {
          :client_ref => default_client_ref,
          :host       => @queue_host,
          :port       => @queue_port,
          :protocol   => :Kafka
        }
      end

      def default_client_ref
        ENV['HOSTNAME'].presence || SecureRandom.hex(4)
      end
    end
  end
end
