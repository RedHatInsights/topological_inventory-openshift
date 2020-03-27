require "sources-api-client"

module TopologicalInventory
  module Openshift
    module Operations
      class Source
        include Logging
        STATUS_AVAILABLE, STATUS_UNAVAILABLE = %w[available unavailable].freeze

        attr_accessor :params, :identity, :metrics, :source_id

        def initialize(params = {}, identity = nil, metrics = nil)
          @params   = params
          @identity = identity
          @metrics  = metrics
          @source_id = nil
        end

        def availability_check
          source_id = params["source_id"]
          unless source_id
            logger.error("Missing source_id for the availability_check request")
            return
          end

          source = SourcesApiClient::Source.new
          source.availability_status = connection_check(source_id)

          begin
            api_client.update_source(source_id, source)
          rescue SourcesApiClient::ApiError => e
            logger.error("Failed to update Source id:#{source_id} - #{e.message}")
          end
          logger.info("Source#availability_check completed: Source #{source_id} is #{source.availability_status}")
        end

        private

        def connection_check(source_id)
          endpoints = api_client.list_source_endpoints(source_id)&.data || []
          endpoint = endpoints.find(&:default)
          return STATUS_UNAVAILABLE unless endpoint

          endpoint_authentications = api_client.list_endpoint_authentications(endpoint.id.to_s).data || []
          return STATUS_UNAVAILABLE if endpoint_authentications.empty?

          auth_id = endpoint_authentications.first.id
          auth = Core::AuthenticationRetriever.new(auth_id, request_identity).process
          return STATUS_UNAVAILABLE unless auth

          connection_manager = TopologicalInventory::Openshift::Connection.new
          connection_manager.connect("openshift", :host => endpoint.host, :port => endpoint.port, :token => auth.password)

          STATUS_AVAILABLE
        rescue => e
          logger.error("Failed to connect to Source id:#{source_id} - #{e.message}")
          STATUS_UNAVAILABLE
        end

        def request_identity
          @request_identity ||= { "x-rh-identity" => Base64.strict_encode64({ "identity" => { "account_number" => params["external_tenant"], "user" => { "is_org_admin" => true }}}.to_json) }
        end

        def api_client
          @api_client ||= begin
            api_client = SourcesApiClient::ApiClient.new
            api_client.default_headers.merge!(request_identity)
            SourcesApiClient::DefaultApi.new(api_client)
          end
        end
      end
    end
  end
end
