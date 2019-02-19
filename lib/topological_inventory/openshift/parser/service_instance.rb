module TopologicalInventory::Openshift
  class Parser
    module ServiceInstance
      def parse_service_instances(service_instances)
        service_instances.each { |si| parse_service_instance(si) }
        collections[:service_instances]
      end

      def parse_service_instance(service_instance)
        cluster_service_class_name = service_instance.spec&.clusterServiceClassRef&.name
        cluster_service_plan_name  = service_instance.spec&.clusterServicePlanRef&.name

        service_offering = lazy_find(:service_offerings, :source_ref => cluster_service_class_name) if cluster_service_class_name
        service_plan     = lazy_find(:service_plans, :source_ref => cluster_service_plan_name) if cluster_service_plan_name

        service_instance = collections.service_instances.build(
          :source_ref        => service_instance.spec.externalID,
          :name              => service_instance.spec.externalName,
          :source_created_at => service_instance.metadata.creationTimestamp,
          :service_offering  => service_offering,
          :service_plan      => service_plan,
        )

        service_instance
      end

      def parse_service_instance_notice(notice)
        service_instance = parse_service_instance(notice.object)
        archive_entity(service_instance, notice.object) if notice.type == "DELETED"
      end
    end
  end
end
