require "openshift/mock/entity"

module Openshift
  module Mock
    class Entity::ClusterServiceClass < Entity
      attr_reader :externalID, :externalName, :description

      def initialize
        super
        @externalName = 'mock-cluster-svc-class'
        @externalID   = 'cluster-svc-class-uid'
        @description  = 'Cluster Service Class'
      end

      def spec
        self
      end
    end
  end
end
