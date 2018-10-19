require "openshift/mock/entity"

module Openshift
  module Mock
    class Entity::ServiceInstance < Entity
      attr_reader :externalID, :externalName

      class ClusterServiceClassRef
        def self.name
          "cluster-svc-class-uid"
        end
      end

      class ClusterServicePlanRef
        def self.name
          "cluster-svc-plan-uid"
        end
      end

      def initialize
        super
        @externalName = 'mock-service-instance'
        @externalID  = 'service-instance-uid'
      end

      def spec
        self
      end

      def clusterServiceClassRef
        ClusterServiceClassRef
      end

      def clusterServicePlanRef
        ClusterServicePlanRef
      end
    end
  end
end
