require "more_core_extensions/core_ext/string/iec60027_2"

module Openshift
  class Parser
    module Node
      def parse_nodes(nodes)
        nodes.each { |node| parse_node(node) }
        collections[:container_nodes]
      end

      def parse_node(node)
        node_status = node.status
        if node_status
          cpus = node_status.capacity&.cpu
          memory = node_status.capacity&.memory&.iec_60027_2_to_i
        end

        container_node =  TopologicalInventory::IngressApi::Client::ContainerNode.new(
          :source_ref        => node.metadata.uid,
          :name              => node.metadata.name,
          :resource_version  => node.metadata.resourceVersion,
          :cpus              => cpus,
          :memory            => memory,
          :source_created_at => node.metadata.creationTimestamp,
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
