module Openshift
  class Parser
    module Node
      def parse_nodes(nodes)
        nodes.each { |node| parse_node(node) }
        collections[:container_nodes]
      end

      def parse_node(node)
        if node.status
          cpus = node.status.capacity&.cpu
          memory = parse_quantity(node.status.capacity&.memory)
        end

        container_node = TopologicalInventory::IngressApi::Client::ContainerNode.new(
          parse_base_item(node).merge(
            :cpus   => cpus,
            :memory => memory,
            :lives_on => vm_cross_link(node.spec.providerID),
          )
        )

        collections[:container_nodes].data << container_node

        container_node
      end

      def parse_node_notice(notice)
        container_node = parse_node(notice.object)
        archive_entity(container_node, notice.object) if notice.type == "DELETED"
      end

      def vm_cross_link(provider_id)
        return if provider_id.nil?

        # AWS providerID format aws:///us-west-2b/i-02ca66d00f6485e3e
        _, instance_uri = provider_id.split("://", 2)
        uid_ems = instance_uri.split("/").last

        lazy_find(:cross_link_vms, {:uid_ems => uid_ems})
      end
    end
  end
end
