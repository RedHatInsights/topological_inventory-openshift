module TopologicalInventory::Openshift
  class Parser
    module ClusterServicePlan
      def parse_cluster_service_plans(cluster_service_plans)
        cluster_service_plans.each { |csp| parse_cluster_service_plan(csp) }
        collections[:service_plans]
      end

      def parse_cluster_service_plan(service_plan)
        cluster_service_class_name = service_plan.spec&.clusterServiceClassRef&.name
        service_offering = lazy_find(:service_offerings, :source_ref => service_plan&.spec&.clusterServiceClassRef&.name) if cluster_service_class_name

        service_plan_data = TopologicalInventoryIngressApiClient::ServicePlan.new(
          :source_ref        => service_plan.spec.externalID,
          :name              => service_plan.spec.externalName,
          :description       => service_plan.spec.description,
          :resource_version  => service_plan.metadata&.resourceVersion,
          :source_created_at => service_plan.metadata.creationTimestamp,
          :create_json_schema => service_plan.spec&.instanceCreateParameterSchema,
          :service_offering  => service_offering,
        )

        collections[:service_plans].data << service_plan_data

        service_plan_data
      end

      def parse_cluster_service_plan_notice(notice)
        service_plan = parse_cluster_service_plan(notice.object)
        archive_entity(service_plan, notice.object) if notice.type == "DELETED"
      end
    end
  end
end
