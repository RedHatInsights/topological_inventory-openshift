require "active_support/core_ext/enumerable"

module Openshift
  class Parser
    module Pod
      def parse_pods(pods)
        pods.each { |pod| parse_pod(pod) }
        collections[:container_groups]
      end

      def parse_pod(pod)
        container_group =  TopologicalInventory::IngressApi::Client::ContainerGroup.new(
          parse_base_item(pod).merge(
            :ipaddress         => pod.status&.podIP,
            :container_node    => lazy_find_node(pod.spec&.nodeName),
            :container_project => lazy_find_namespace(pod.metadata&.namespace),
          )
        )

        collections[:container_groups].data << container_group
        collections[:containers].data.concat(parse_containers(pod))

        container_group
      end

      def parse_pod_notice(notice)
        container_group = parse_pod(notice.object)
        archive_entity(container_group, notice.object) if notice.type == "DELETED"
      end

      def parse_containers(pod)
        pod.spec.containers.map do |container|
          TopologicalInventory::IngressApi::Client::Container.new(
            :container_group    => lazy_find(:container_groups, {:source_ref => pod.metadata.uid}),
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
