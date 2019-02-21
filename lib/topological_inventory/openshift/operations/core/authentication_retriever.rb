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

            scheme     = TopologicalInventoryApiClient.configure.scheme
            host, port = TopologicalInventoryApiClient.configure.host.split(":")

            uri = URI::Generic.build(
              :scheme => scheme,
              :host   => host,
              :port   => port,
              :path   => "/internal/v0.0/authentications/#{@id}",
              :query  => "expose_encrypted_attribute[]=password"
            )

            request_options = {
              :method  => :get,
              :url     => uri.to_s,
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
