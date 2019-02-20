require "topological_inventory/openshift/operations/core/retriever"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        class AuthenticationRetriever < Retriever
          def process
            authentication_id = @api_instance.list_endpoint_authentications(@id.to_s).data[0].id
            headers = {
              "Content-Type" => "application/json"
            }
            request_options = {
              :method  => :get,
              :url     => "#{ENV["TOPOLOGICAL_INVENTORY_URL"]}/internal/v0.0/authentications/#{authentication_id}?expose_encrypted_attribute[]=password",
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
