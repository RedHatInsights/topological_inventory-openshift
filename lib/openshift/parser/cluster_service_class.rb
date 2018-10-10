module Openshift
  class Parser
    module ClusterServiceClass
      def parse_cluster_service_classes(cluster_service_classes)
        cluster_service_classes.each { |csc| parse_cluster_service_class(csc) }
      end

      def parse_cluster_service_class(service_class)
        service_offering = TopologicalInventory::IngressApi::Client::ServiceOffering.new(
          :source_ref  => service_class.spec.externalID,
          :name        => service_class.spec&.externalName,
          :description => service_class.spec&.description,
        )

        collections[:service_offerings] ||= TopologicalInventory::IngressApi::Client::InventoryCollection.new(:name => :service_offerings)
        collections[:service_offerings].data << service_offering
      end

      def parse_cluster_service_class_notice(notice)
        parse_cluster_service_class(notice.object)
      end
    end
  end
end
