module Openshift
  class Parser
    class Namespace < Openshift::Parser
      def parse(namespaces)
        namespaces.each { |ns| parse_namespace(ns) }
      end

      def parse_namespace(namespace)
        collection.data << TopologicalInventory::IngressApi::Client::ContainerProject.new(
          :name              => namespace.metadata.name,
          :source_ref        => namespace.metadata.uid,
          :resource_version  => namespace.metadata.resourceVersion,
        )
      end

      def parse_notice(notice)
      end

      def inventory_collection_name
        :container_projects
      end
    end
  end
end
