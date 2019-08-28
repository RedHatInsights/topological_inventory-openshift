require "topological_inventory/openshift/logging"
require "topological_inventory/openshift/operations/service_plan"
require "topological_inventory/openshift/operations/source"

module TopologicalInventory
  module Openshift
    module Operations
      class Processor
        include Logging

        def initialize(model, method, payload, metrics)
          self.model           = model
          self.method          = method
          self.params          = payload["params"]
          self.identity        = payload["request_context"]
          self.metrics         = metrics
        end

        def process
          logger.info("Processing #{model}##{method} [#{params}]...")

          if Operations.const_defined?(model)
            impl = Operations.const_get(model).new(params, identity, metrics)
            if impl.respond_to?(method)
              result = impl.send(method)
              logger.info("Processing #{model}##{method} [#{params}]...Complete")
              return result
            end
          end
          logger.error("#{model}.#{method} is not implemented")
        end

        private

        attr_accessor :identity, :model, :method, :metrics, :params
      end
    end
  end
end
