module Openshift
  class Parser
    class ClusterServicePlan < Openshift::Parser
      def parse(service_cluster_plans)
        service_cluster_plans.each { |scp| parse_cluster_service_plan(scp) }
      end

      def parse_cluster_service_plan(service_plan)
        collection.data << TopologicalInventory::IngressApi::Client::ServiceParametersSet.new(
          :source_ref       => service_plan.spec.externalID,
          :name             => service_plan.metadata&.name,
          :resource_version => service_plan.metadata&.resourceVersion,
        )
      end

      def parse_notice(notice)
      end

      def inventory_collection_name
        :service_parameters_sets
      end
    end
  end
end
