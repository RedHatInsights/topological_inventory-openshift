require "openshift/mock/entity"

module Openshift
  module Mock
    class Entity::Namespace < Entity
      def initialize
        super
        @name = "mock-namespace"
        @uid  = "namespace-uuid"
      end
    end
  end
end
