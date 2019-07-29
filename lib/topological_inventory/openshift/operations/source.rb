require "sources-api-client"

module TopologicalInventory
  module Openshift
    module Operations
      module Source
        STATUS_AVAILABLE, STATUS_UNAVAILABLE = %w[available unavailable].freeze

        def self.availability_check(params)
          source_id = params["source_id"]
          raise "Missing source_id for the availability_check request" unless source_id

          # Let's skip the request if it's older than a minute ago.
          if params["timestamp"]
            return if params["timestamp"] < (Time.now.utc - 1.minute)
          end

          api_client = SourcesApiClient::DefaultApi.new

          source = SourcesApiClient::Source.new
          source.availability_status = connection_check(api_client, source_id)

          begin
            api_client.update_source(source_id, source)
          rescue SourcesApiClient::ApiError => e
            puts "Failed to update Source id:#{source_id} - #{e}"
          end
        end

        def self.connection_check(api_client, source_id)
          endpoints = api_client.list_source_endpoints(source_id)&.data || []
          endpoint = endpoints.find(&:default)
          return STATUS_UNAVAILABLE unless endpoint

          endpoint_authentications = api_client.list_endpoint_authentications(endpoint.id.to_s).data || []
          return STATUS_UNAVAILABLE if endpoint_authentications.empty?

          auth_id = endpoint_authentications.first.id
          auth = Core::AuthenticationRetriever.new(auth_id, nil).process
          return STATUS_UNAVAILABLE unless auth

          connection_manager = TopologicalInventory::Openshift::Connection.new
          connection_manager.connect("openshift", :host => endpoint.host, :port => endpoint.port, :token => auth.password)

          STATUS_AVAILABLE
        rescue SourcesApiClient::ApiError => e
          puts "Failed to connect to Source id:#{source_id} - #{e}"
          STATUS_UNAVAILABLE
        end
      end
    end
  end
end
