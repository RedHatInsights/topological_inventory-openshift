require "topological_inventory/openshift/operations/core/retriever"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        class ServiceOfferingRetriever < Retriever
          def process
            @api_instance.show_service_offering(@id.to_s)
          end
        end
      end
    end
  end
end
