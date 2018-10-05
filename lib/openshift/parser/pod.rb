module Openshift
  class Parser
    class Pod < Openshift::Parser
      def parse(pods)
        pods.each { |pod| parse_pod(pod) }
      end

      def parse_pod(pod)
        container_project_lazy_link = TopologicalInventory::Client::InventoryObjectLazy.new(
          :inventory_collection_name => :container_projects,
          :reference                 => {
            :name => pod.metadata.namespace
          },
          :ref                       => :by_name,
        )

        collection.data << TopologicalInventory::Client::ContainerGroup.new(
          parse_base_item(pod).merge(
            :ipaddress         => pod.status&.podIP,
            :container_project => container_project_lazy_link,
          )
        )
      end

      def parse_notice(notice)
      end

      def inventory_collection_name
        :container_groups
      end
    end
  end
end
