require "topological_inventory-api-client"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        class Retriever
          def initialize(id)
            @id = id
            uri = URI.parse(ENV["TOPOLOGICAL_INVENTORY_URL"])
            TopologicalInventoryApiClient.configure do |config|
              config.base_path = "#{ENV["PATH_PREFIX"]}/topological-inventory/v0.0/"
              config.scheme = uri.scheme
              config.host = "#{uri.host}:#{uri.port}"
            end

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
