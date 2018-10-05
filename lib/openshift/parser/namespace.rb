module Openshift
  class Parser
    class Namespace < Openshift::Parser
      def parse(namespaces)
        namespaces.each { |ns| parse_namespace(ns) }
      end

      def parse_namespace(namespace)
        collection.data << TopologicalInventory::Client::ContainerProject.new(
          parse_base_item(namespace).except(:namespace)
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
