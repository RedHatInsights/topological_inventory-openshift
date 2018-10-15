module Openshift
  class Parser
    module ClusterServicePlan
      def parse_cluster_service_plans(cluster_service_plans)
        cluster_service_plans.each { |csp| parse_cluster_service_plan(csp) }
      end

      def parse_cluster_service_plan(service_plan)
        service_parameters_set = TopologicalInventory::IngressApi::Client::ServiceParametersSet.new(
          :source_ref        => service_plan.spec.externalID,
          :name              => service_plan.metadata&.name,
          :resource_version  => service_plan.metadata&.resourceVersion,
          :source_created_at => service_plan.metadata.creationTimestamp,
        )

        collections[:service_parameters_sets] ||= TopologicalInventory::IngressApi::Client::InventoryCollection.new(:name => :service_parameters_sets)
        collections[:service_parameters_sets].data << service_parameters_set

        service_parameters_set
      end

      def parse_cluster_service_plan_notice(notice)
        service_parameters_set = parse_cluster_service_plan(notice.object)
        archive_entity(service_parameters_set, notice.object) if notice.type == "DELETED"
      end
    end
  end
end
