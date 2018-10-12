module Openshift
  class Parser
    module Template
      def parse_templates(templates)
        templates.each { |template| parse_template(template) }
      end

      def parse_template(template)
        container_template = TopologicalInventory::IngressApi::Client::ContainerTemplate.new(parse_base_item(template))

        collections[:container_templates] ||= TopologicalInventory::IngressApi::Client::InventoryCollection.new(:name => :container_templates)
        collections[:container_templates].data << container_template
      end

      def parse_template_notice(notice)
        parse_template(notice.object)
      end
    end
  end
end
