module Openshift
  class Parser
    class ServiceInstance < Openshift::Parser
      def parse(service_instances)
        service_instances.each { |si| parse_service_instance(si) }
      end

      def parse_service_instance(service_instance)
        collection.data << TopologicalInventory::IngressApi::Client::ServiceInstance.new(
          :source_ref => service_instance.spec.externalID,
          :name       => service_instance.metadata.name,
        )
      end

      def parse_notice(notice)
      end

      def inventory_collection_name
        :service_instances
      end
    end
  end
end
