require "sources-api-client"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        class AuthenticationRetriever
          def initialize(id, identity = nil)
            @id       = id.to_s
            @identity = identity
          end

          def process
            headers = {
              "Content-Type" => "application/json"
            }

            headers.merge!(@identity) if @identity.present?

            scheme     = SourcesApiClient.configure.scheme
            host, port = SourcesApiClient.configure.host.split(":")

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
            SourcesApiClient::Authentication.new(JSON.parse(response.body))
          end
        end
      end
    end
  end
end
