require "openshift/mock/entity"

module Openshift
  module Mock
    class Entity::Template < Entity
      def initialize
        super
        @name = 'mock-template'
        @uid  = 'template-uid'
      end
    end
  end
end
