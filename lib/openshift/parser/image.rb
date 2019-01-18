module Openshift
  class Parser
    module Image
      def parse_images(images)
        images.each { |image| parse_image(image) }
        collections[:container_images]
      end

      def parse_image(image)
        image_name = parse_image_name(image)

        container_image = TopologicalInventory::IngressApi::Client::ContainerImage.new(
          parse_base_item(image).merge(
            :name => image_name
          )
        )

        collections[:container_images].data << container_image
        parse_image_tags(container_image.source_ref, image.metadata&.labels&.to_h)
        parse_image_tags(container_image.source_ref, image.dockerImageMetadata&.Config&.Labels&.to_h)

        container_image
      end

      def parse_image_notice(notice)
        container_image = parse_image(notice.object)
        archive_entity(container_image, notice.object) if notice.type == "DELETED"
      end

      private

      def parse_image_tags(source_ref, tags)
        (tags || {}).each do |key, value|
          collections[:container_image_tags].data << TopologicalInventory::IngressApi::Client::ContainerImageTag.new(
            :container_image => lazy_find(:container_images, :source_ref => source_ref),
            :tag             => lazy_find(:tags, :name => key),
            :value           => value,
          )
        end
      end

      def parse_image_name(image)
        docker_pullable_re = %r{
          \A
            (?:(?:
              (?<host>([^\.:/]+\.)+[^\.:/]+)|
              (?:(?<host2>[^:/]+)(?::(?<port>\d+)))|
              (?<localhost>localhost)
            )/)?
            (?<name>(?:[^:/@]+/)*[^/:@]+)
            (?::(?<tag>[^:/@]+))?
            (?:\@(?<digest>.+))?
          \z
        }x

        image_parts = docker_pullable_re.match(image.dockerImageReference)

        image_parts[:name]
      end
    end
  end
end
