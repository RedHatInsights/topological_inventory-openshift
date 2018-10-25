require "openshift/mock/entity"

module Openshift
  module Mock
    class Entity::Node < Entity
      attr_reader :cpu, :memory

      def initialize
        super
        @name   = "mock-node"
        @uid    = "node-uuid"
        @cpu    = "1"
        @memory = "100"
      end

      def status
        self
      end

      def capacity
        self
      end
    end
  end
end
