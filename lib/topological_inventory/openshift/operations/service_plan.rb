require "topological_inventory/openshift/operations/order/request"

module TopologicalInventory
  module Openshift
    module Operations
      class ServicePlan
        include Logging
        include Core::TopologyApiClient

        attr_accessor :params, :identity, :metrics

        def initialize(params = {}, identity = nil, metrics = nil)
          @params   = params
          @identity = identity
          @metrics  = metrics
        end

        def order
          Order::Request.new(params, identity, metrics).run
        end
      end
    end
  end
end
