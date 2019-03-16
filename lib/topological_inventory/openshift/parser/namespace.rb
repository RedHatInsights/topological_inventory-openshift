module TopologicalInventory::Openshift
  class Parser
    module Namespace
      def parse_namespaces(namespaces)
        namespaces.each { |ns| parse_namespace(ns) }
        collections[:container_projects]
      end

      def parse_namespace(namespace)
        container_project = collections.container_projects.build(
          parse_base_item(namespace).merge(
            :status_phase => namespace.status&.phase
          )
        )

        parse_namespace_tags(container_project.source_ref, namespace.metadata&.labels&.to_h)

        container_project
      end

      def parse_namespace_notice(notice)
        container_project = parse_namespace(notice.object)
        archive_entity(container_project, notice.object) if notice.type == "DELETED"
      end

      private

      def parse_namespace_tags(source_ref, tags)
        (tags || {}).each do |key, value|
          collections.container_project_tags.build(
            :container_project => lazy_find(:container_projects, :source_ref => source_ref),
            :tag               => lazy_find(:tags, :name => key, :value => value),
          )
        end
      end
    end
  end
end
