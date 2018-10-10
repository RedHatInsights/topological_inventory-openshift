module Openshift
  class Parser
    module ServiceInstance
      def parse_service_instances(service_instances)
        service_instances.each { |si| parse_service_instance(si) }
      end

      def parse_service_instance(service_instance)
        service_instance = TopologicalInventory::IngressApi::Client::ServiceInstance.new(
          :source_ref => service_instance.spec.externalID,
          :name       => service_instance.metadata.name,
        )

        collections[:service_instances] ||= TopologicalInventory::IngressApi::Client::InventoryCollection.new(:name => :service_instances)
        collections[:service_instances].data << service_instance
      end

      def parse_service_instance_notice(notice)
        parse_service_instance(notice.object)
      end
    end
  end
end
