require "topological_inventory/openshift/logging"
require "topological_inventory-api-client"
require "topological_inventory/openshift/operations/core/topology_api_client"
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
          logger.info(status_log_msg)

          impl = "#{Operations}::#{model}".safe_constantize&.new(params, identity, metrics)
          if impl&.respond_to?(method)
            result = impl&.send(method)

            logger.info(status_log_msg("Complete"))
            result
          else
            logger.warn(status_log_msg("Not Implemented!"))
            if params['task_id']
              update_task(params['task_id'],
                          :state   => "completed",
                          :status  => "error",
                          :context => {:error => "#{model}##{method} not implemented"})
            end
          end
        end

        private

        attr_accessor :identity, :model, :method, :metrics, :params

        def status_log_msg(status = nil)
          "Processing #{model}##{method} [#{params}]...#{status}"
        end
      end
    end
  end
end
