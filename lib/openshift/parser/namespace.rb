module Openshift
  class Parser
    module Namespace
      def parse_namespaces(namespaces)
        namespaces.each { |ns| parse_namespace(ns) }
        collections[:container_projects]
      end

      def parse_namespace(namespace)
        container_project = TopologicalInventory::IngressApi::Client::ContainerProject.new(
          parse_base_item(namespace)
        )

        collections[:container_projects].data << container_project

        container_project
      end

      def parse_namespace_notice(notice)
        container_project = parse_namespace(notice.object)
        archive_entity(container_project, notice.object) if notice.type == "DELETED"
      end
    end
  end
end
