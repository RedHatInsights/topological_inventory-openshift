require "openshift/mock/entity"

module Openshift
  module Mock
    class Entity::ClusterServicePlan < Entity
      attr_reader :externalID, :externalName, :description, :instanceCreateParameterSchema

      class ClusterServiceClassRef
        def self.name
          "cluster-svc-class-uid"
        end
      end

      def initialize
        super
        @externalName = 'mock-cluster-svc-plan'
        @externalID   = 'cluster-svc-plan-uid'
        @description  = 'Cluster Service Plan'
        @instanceCreateParameterSchema = ::Kubeclient::Resource.new({"type": "object", "$schema": "http://json-schema.org/draft-04/schema", "additionalProperties": false})
      end

      def spec
        self
      end

      def clusterServiceClassRef
        ClusterServiceClassRef
      end
    end
  end
end
