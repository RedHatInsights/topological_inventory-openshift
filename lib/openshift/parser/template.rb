module Openshift
  class Parser
    class Template < Openshift::Parser
      def parse(templates)
        templates.each { |template| parse_template(template) }
      end

      def parse_template(template)
        collection.data << TopologicalInventory::Client::ContainerTemplate.new(
          parse_base_item(template)
        )
      end

      def parse_notice(notice)
      end

      def inventory_collection_name
        :container_templates
      end
    end
  end
end
