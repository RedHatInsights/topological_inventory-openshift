require "topological_inventory-api-client"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        class Retriever
          def initialize(id)
            @id = id
            @api_instance = TopologicalInventoryApiClient::DefaultApi.new
          end

          def process
            nil # Override in subclasses
          end
        end
      end
    end
  end
end
