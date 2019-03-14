module TopologicalInventory::Openshift
  class Parser
    module ResourceQuota
      def parse_resource_quotas(resources_quotas)
        resources_quotas.each { |resources_quota| parse_resource_quota(resources_quota) }

        collections[:container_resource_quotas]
      end

      def parse_resource_quota(resource_quota)
        collections.container_resource_quotas.build(
          parse_base_item(resource_quota).merge(
            :container_project => lazy_find_namespace(resource_quota.metadata&.namespace),
            :status            => resource_quota.status&.to_h,
            :spec              => resource_quota.spec&.to_h,
          )
        )
      end

      def parse_resource_quota_notice(notice)
        resource_quota = parse_resource_quota(notice.object)
        archive_entity(resource_quota, notice.object) if notice.type == "DELETED"
      end
    end
  end
end
