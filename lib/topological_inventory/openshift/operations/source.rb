require "sources-api-client"

module TopologicalInventory
  module Openshift
    module Operations
      module Source
        def self.availability_check(params)
          source_id = params["source_id"]
          raise "Missing source_id for the availability_check request" unless source_id

          # Let's skip the request if it's older than a minute ago.
          if params["timestamp"]
            return if params["timestamp"] < (Time.now.utc - 1.minute)
          end

          puts "Running: availability_check for Source id: #{source_id}"

          api_client = SourcesApiClient::DefaultApi.new

          # TODO: Connection check

          source = SourcesApiClient::Source.new
          source.availability_status = "available"

          begin
            api_client.update_source(source_id, source)
          rescue SourcesApiClient::ApiError => e
            puts "Failed to update Source id:#{source_id} - #{e}"
          end
        end
      end
    end
  end
end
