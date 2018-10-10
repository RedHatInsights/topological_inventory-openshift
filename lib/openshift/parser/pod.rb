module Openshift
  class Parser
    module Pod
      def parse_pods(pods)
        pods.each { |pod| parse_pod(pod) }
      end

      def parse_pod(pod)
        container_project_lazy_link = TopologicalInventory::IngressApi::Client::InventoryObjectLazy.new(
          :inventory_collection_name => :container_projects,
          :reference                 => {
            :name => pod.metadata.namespace
          },
          :ref                       => :by_name,
        )

        container_group =  TopologicalInventory::IngressApi::Client::ContainerGroup.new(
          parse_base_item(pod).merge(
            :ipaddress         => pod.status&.podIP,
            :container_project => container_project_lazy_link,
          )
        )

        collections[:container_groups] ||= TopologicalInventory::IngressApi::Client::InventoryCollection.new(:name => :container_groups)
        collections[:container_groups].data << container_group
      end

      def parse_pod_notice(notice)
        parse_pod(notice.object)
      end
    end
  end
end
