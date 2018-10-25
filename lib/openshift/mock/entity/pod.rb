require "openshift/mock/entity"

module Openshift
  module Mock
    class Entity::Pod < Entity
      attr_reader :podIP, :nodeName

      def initialize
        super
        @name     = "mock-pod"
        @podIP    = "127.0.0.1"
        @nodeName = "mock-node"
        @uid      = "pod-uuid"
      end

      def status
        self
      end

      def spec
        self
      end
    end
  end
end
