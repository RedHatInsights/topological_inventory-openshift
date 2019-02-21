require "topological_inventory/openshift/operations/core/source_retriever"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        RSpec.describe SourceRetriever do
          let(:subject) { described_class.new(123) }

          describe "#process" do
            let(:url) { "http://localhost:3000/r/insights/platform/topological-inventory/v0.1/sources/123" }
            let(:headers) { {"Content-Type" => "application/json"} }
            let(:dummy_response) { {"name" => "dummy"} }

            before do
              stub_request(:get, url).with(:headers => headers).to_return(:body => dummy_response.to_json, :headers => headers)
            end

            around do |e|
              url = ENV["TOPOLOGICAL_INVENTORY_URL"]
              ENV["TOPOLOGICAL_INVENTORY_URL"] = "http://localhost:3000"

              e.run

              ENV["TOPOLOGICAL_INVENTORY_URL"] = url
            end

            it "returns the source response" do
              source = subject.process
              expect(source.class).to eq(TopologicalInventoryApiClient::Source)
              expect(source.name).to eq("dummy")
            end
          end
        end
      end
    end
  end
end
