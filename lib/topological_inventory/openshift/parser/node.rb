module TopologicalInventory::Openshift
  class Parser
    module Node
      def parse_nodes(nodes)
        nodes.each { |node| parse_node(node) }
        collections[:container_nodes]
      end

      def parse_node(node)
        node_info = node.spec.to_h

        if node.status
          cpus   = parse_quantity(node.status.capacity&.cpu)
          memory = parse_quantity(node.status.capacity&.memory)
          pods   = node.status.capacity&.pods

          allocatable_cpus   = parse_quantity(node.status.allocatable&.cpu)
          allocatable_memory = parse_quantity(node.status.allocatable&.memory)
          allocatable_pods   = parse_quantity(node.status.allocatable&.pods)

          conditions = (node.status&.conditions || []).map(&:to_h)
          addresses  = (node.status&.addresses || []).map(&:to_h)

          node_info.merge!(node.status&.nodeInfo&.to_h || {})
        end

        container_node = collections.container_nodes.build(
          parse_base_item(node).merge(
            :cpus               => cpus,
            :memory             => memory,
            :pods               => pods,
            :allocatable_cpus   => allocatable_cpus,
            :allocatable_memory => allocatable_memory,
            :allocatable_pods   => allocatable_pods,
            :conditions         => conditions,
            :addresses          => addresses,
            :node_info          => node_info,
            :lives_on           => vm_cross_link(node.spec.providerID),
          )
        )

        parse_node_tags(container_node.source_ref, node.metadata&.labels&.to_h)

        container_node
      end

      def parse_node_notice(notice)
        container_node = parse_node(notice.object)
        archive_entity(container_node, notice.object) if notice.type == "DELETED"
      end

      private

      def parse_node_tags(source_ref, tags)
        (tags || {}).each do |key, value|
          collections.container_node_tags.build(
            :container_node => lazy_find(:container_nodes, :source_ref => source_ref),
            :tag            => lazy_find(:tags, :name => key, :value => value, :namespace => "openshift"),
          )
        end
      end

      def vm_cross_link(provider_id)
        return if provider_id.nil?

        # AWS providerID format aws:///us-west-2b/i-02ca66d00f6485e3e
        _, instance_uri = provider_id.split("://", 2)
        uid_ems = instance_uri.split("/").last

        lazy_find(:cross_link_vms, :uid_ems => uid_ems)
      end
    end
  end
end
