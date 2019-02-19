require "topological_inventory/openshift/operations/core/retriever"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        class SourceRetriever < Retriever
          def process
            @api_instance.show_source(@id.to_s)
          end
        end
      end
    end
  end
end
