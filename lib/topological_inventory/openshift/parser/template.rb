module TopologicalInventory::Openshift
  class Parser
    module Template
      def parse_templates(templates)
        templates.each { |template| parse_template(template) }
        collections[:container_templates]
      end

      def parse_template(template)
        container_template = collections.container_templates.build(
          parse_base_item(template).merge(
            :container_project => lazy_find_namespace(template.metadata&.namespace)
          )
        )

        parse_template_tags(container_template.source_ref, template.metadata&.labels&.to_h)

        container_template
      end

      def parse_template_notice(notice)
        container_template = parse_template(notice.object)
        archive_entity(container_template, notice.object) if notice.type == "DELETED"
      end

      private

      def parse_template_tags(source_ref, tags)
        (tags || {}).each do |key, value|
          collections.container_template_tags.build(
            :container_template => lazy_find(:container_templates, :source_ref => source_ref),
            :tag                => lazy_find(:tags, :name => key, :value => value, :namespace => "openshift"),
          )
        end
      end
    end
  end
end
