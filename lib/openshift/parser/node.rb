require "more_core_extensions/core_ext/string/iec60027_2"

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
          memory = node.status.capacity&.memory&.iec_60027_2_to_i
        end

        container_node = TopologicalInventory::IngressApi::Client::ContainerNode.new(
          parse_base_item(node).merge(
            :cpus   => cpus,
            :memory => memory,
          )
        )

        collections[:container_nodes].data << container_node

        container_node
      end

      def parse_node_notice(notice)
        container_node = parse_node(notice.object)
        archive_entity(container_node, notice.object) if notice.type == "DELETED"
      end
    end
  end
end
