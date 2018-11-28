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

        container_image
      end

      def parse_image_notice(notice)
        container_image = parse_image(notice.object)
        archive_entity(container_image, notice.object) if notice.type == "DELETED"
      end

      private

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
