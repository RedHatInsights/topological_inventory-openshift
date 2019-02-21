require "topological_inventory/openshift/operations/core/retriever"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        class AuthenticationRetriever < Retriever
          def process
            headers = {
              "Content-Type" => "application/json"
            }
            url = URI.join(ENV["TOPOLOGICAL_INVENTORY_URL"], "/internal/v0.0/authentications/#{@id}?expose_encrypted_attribute[]=password")
            request_options = {
              :method  => :get,
              :url     => url.to_s,
              :headers => headers
            }
            response = RestClient::Request.new(request_options).execute
            TopologicalInventoryApiClient::Authentication.new(JSON.parse(response.body))
          end
        end
      end
    end
  end
end
