require "topological_inventory/openshift/operations/core/retriever"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        class SourceEndpointsRetriever < Retriever
          def process
            @api_instance.list_source_endpoints(@id.to_s)
          end
        end
      end
    end
  end
end
