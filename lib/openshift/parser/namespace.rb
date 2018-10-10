module Openshift
  class Parser
    module Namespace
      def parse_namespaces(namespaces)
        namespaces.each { |ns| parse_namespace(ns) }
      end

      def parse_namespace(namespace)
        container_project = TopologicalInventory::IngressApi::Client::ContainerProject.new(
          :name              => namespace.metadata.name,
          :source_ref        => namespace.metadata.uid,
          :resource_version  => namespace.metadata.resourceVersion,
        )

        collections[:container_projects] ||= TopologicalInventory::IngressApi::Client::InventoryCollection.new(:name => :container_projects)
        collections[:container_projects].data << container_project
      end

      def parse_namespace_notice(notice)
        parse_namespace(notice.object)
      end
    end
  end
end
