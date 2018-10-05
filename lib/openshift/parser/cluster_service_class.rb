module Openshift
  class Parser
    class ClusterServiceClass < Openshift::Parser
      def parse(service_cluster_classes)
        service_cluster_classes.each { |scc| parse_service_cluster_class(scc) }
      end

      def parse_service_cluster_class(service_class)
        collection.data << TopologicalInventory::Client::ServiceOffering.new(
          :source_ref  => service_class.spec.externalID,
          :name        => service_class.spec&.externalName,
          :description => service_class.spec&.description,
        )
      end

      def parse_notice(notice)
      end

      def inventory_collection_name
        :service_offerings
      end
    end
  end
end
