module Openshift
  class Parser
    module Node
      def parse_nodes(nodes)
        nodes.each { |node| parse_node(node) }
      end

      def parse_node(node)
        node_info = node.status&.nodeInfo
        if node_info
          cpus = node_info.capacity&.cpu
          memory = parse_capacity_field("Node-Memory", node_info.capacity&.memory)
        end

        container_node =  TopologicalInventory::IngressApi::Client::ContainerNode.new(
          :source_ref       => node.metadata.uid,
          :name             => node.metadata.name,
          :resource_version => node.metadata.resourceVersion,
          :cpus             => node.status&.nodeInfo&.capacity&.cpu,
          :memory           => node.status&.nodeInfo&.capacity&.memory,
        )

        collections[:container_nodes] ||= TopologicalInventory::IngressApi::Client::InventoryCollection.new(:name => :container_nodes)
        collections[:container_nodes].data << container_node
      end

      def parse_node_notice(notice)
        parse_node(notice.object)
      end

      private

      def parse_capacity_field(key, val)
        return nil unless val
        begin
          val.iec_60027_2_to_i
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
