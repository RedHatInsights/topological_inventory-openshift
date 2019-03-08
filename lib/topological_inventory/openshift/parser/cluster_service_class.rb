require 'net/https'

module TopologicalInventory::Openshift
  class Parser
    module ClusterServiceClass
      def parse_cluster_service_classes(cluster_service_classes)
        cluster_service_classes.each { |csc| parse_cluster_service_class(csc) }
        parse_icons

        collections[:service_offerings]
      end

      def parse_cluster_service_class(service_class)
        @icons_cache ||= Set.new
        icon_class = (service_class.spec&.externalMetadata || {})["console.openshift.io/iconClass"]
        @icons_cache << icon_class

        service_offering = collections.service_offerings.build(
          :source_ref            => service_class.spec.externalID,
          :name                  => service_class.spec&.externalName,
          :description           => service_class.spec&.description,
          :source_created_at     => service_class.metadata.creationTimestamp,
          :display_name          => service_class.spec&.externalMetadata&.displayName,
          :documentation_url     => service_class.spec&.externalMetadata&.documentationUrl,
          :long_description      => service_class.spec&.externalMetadata&.longDescription,
          :distributor           => service_class.spec&.externalMetadata&.providerDisplayName,
          :support_url           => service_class.spec&.externalMetadata&.supportUrl,
          :service_offering_icon => lazy_find(:service_offering_icons, :source_ref => icon_class)
        )

        parse_service_offering_tags(service_offering.source_ref, service_class.spec&.tags)

        service_offering
      end

      def parse_cluster_service_class_notice(notice)
        service_offering = parse_cluster_service_class(notice.object)
        archive_entity(service_offering, notice.object) if notice.type == "DELETED"
      end

      def parse_icons
        icons_cache = @icons_cache.to_a.compact

        return if icons_cache.empty?

        icons_cache.map do |icon|
          collections.service_offering_icons.build(
            :source_ref => icon,
            :data       => fetch_icon(icon)
          )
        end
      end

      private

      def fetch_icon(icon)
        icon_name        = icon.sub(/^icon\-/, '')
        uri              = URI.parse(
          "https://#{openshift_host}:#{openshift_port}/console/images/logos/#{icon_name}.svg"
        )
        http             = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl     = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request          = Net::HTTP::Get.new(uri.path)
        body = http.request(request).body
        return unless body.start_with?("<svg") # We allow only svg icons

        body
      end

      def parse_service_offering_tags(source_ref, tags)
        (tags || []).each do |key|
          next if key.empty?

          collections.service_offering_tags.build(
            :service_offering => lazy_find(:service_offerings, :source_ref => source_ref),
            :tag              => lazy_find(:tags, :name => key, :value => '')
          )
        end
      end
    end
  end
end
