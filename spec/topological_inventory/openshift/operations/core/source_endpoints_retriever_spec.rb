require "topological_inventory/openshift/operations/core/source_endpoints_retriever"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        RSpec.describe SourceEndpointsRetriever do
          let(:subject) { described_class.new(123) }

          describe "#process" do
            let(:url) { "http://localhost:3000/api/topological-inventory/v0.0/sources/123/endpoints" }
            let(:headers) { {"Content-Type" => "application/json"} }
            let(:dummy_response) { {"data" => [{"host" => "dummy"}]} }

            before do
              stub_request(:get, url).with(:headers => headers).to_return(:body => dummy_response.to_json, :headers => headers)
            end

            around do |e|
              url    = ENV["TOPOLOGICAL_INVENTORY_URL"]
              prefix = ENV["PATH_PREFIX"]

              ENV["TOPOLOGICAL_INVENTORY_URL"] = "http://localhost:3000"
              ENV["PATH_PREFIX"]               = "api"

              e.run

              ENV["TOPOLOGICAL_INVENTORY_URL"] = url
              ENV["PATH_PREFIX"]               = prefix
            end

            it "returns the list of endpoints based on the source" do
              endpoints = subject.process
              expect(endpoints.class).to eq(TopologicalInventoryApiClient::EndpointsCollection)
              expect(endpoints.data.first.class).to eq(TopologicalInventoryApiClient::Endpoint)
              expect(endpoints.data.first.host).to eq("dummy")
            end
          end
        end
      end
    end
  end
end
