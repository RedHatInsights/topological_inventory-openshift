module Openshift
  class Parser
    module ServiceInstance
      def parse_service_instances(service_instances)
        service_instances.each { |si| parse_service_instance(si) }
      end

      def parse_service_instance(service_instance)
        service_instance = TopologicalInventory::IngressApi::Client::ServiceInstance.new(
          :source_ref        => service_instance.spec.externalID,
          :name              => service_instance.metadata.name,
          :source_created_at => service_instance.metadata.creationTimestamp,
        )

        collections[:service_instances] ||= TopologicalInventory::IngressApi::Client::InventoryCollection.new(:name => :service_instances)
        collections[:service_instances].data << service_instance

        service_instance
      end

      def parse_service_instance_notice(notice)
        service_instance = parse_service_instance(notice.object)
        archive_entity(service_instance, notice.object) if notice.type == "DELETED"
      end
    end
  end
end
