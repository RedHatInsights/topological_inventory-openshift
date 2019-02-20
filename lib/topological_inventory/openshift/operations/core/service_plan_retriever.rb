require "topological_inventory/openshift/operations/core/retriever"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        class ServicePlanRetriever < Retriever
          def process
            @api_instance.show_service_plan(@id.to_s)
          end
        end
      end
    end
  end
end
