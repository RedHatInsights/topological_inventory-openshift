require "active_support/core_ext/enumerable"

module TopologicalInventory::Openshift
  class Parser
    module Pod
      def parse_pods(pods)
        pods.each { |pod| parse_pod(pod) }
        collections[:container_groups]
      end

      def parse_pod(pod)
        container_group = collections.container_groups.build(
          parse_base_item(pod).merge(
            :ipaddress         => pod.status&.podIP,
            :container_node    => lazy_find_node(pod.spec&.nodeName),
            :container_project => lazy_find_namespace(pod.metadata&.namespace),
          )
        )

        parse_containers(pod)
        parse_pod_tags(container_group.source_ref, pod.metadata&.labels&.to_h)
        parse_pod_tags(container_group.source_ref, pod.entity&.spec&.nodeSelector&.to_h)

        container_group
      end

      def parse_pod_notice(notice)
        container_group = parse_pod(notice.object)
        archive_entity(container_group, notice.object) if notice.type == "DELETED"
      end

      private

      def parse_pod_tags(source_ref, tags)
        (tags || {}).each do |key, value|
          collections.container_group_tags.build(
            :container_group => lazy_find(:container_groups, :source_ref => source_ref),
            :tag             => lazy_find(:tags, :name => key),
            :value           => value,
          )
        end
      end

      def parse_containers(pod)
        pod.spec.containers.map do |container|
          collections.containers.build(
            :container_group    => lazy_find(:container_groups, {:source_ref => pod.metadata.uid}),
            :container_image    => lazy_find(:container_images, {:source_ref => container.image}),
            :name               => container.name,
            :resource_timestamp => resource_timestamp,
            :cpu_limit          => parse_quantity(container.resources&.limits&.cpu),
            :cpu_request        => parse_quantity(container.resources&.requests&.cpu),
            :memory_limit       => parse_quantity(container.resources&.limits&.memory),
            :memory_request     => parse_quantity(container.resources&.requests&.memory),
          )
        end
      end
    end
  end
end
