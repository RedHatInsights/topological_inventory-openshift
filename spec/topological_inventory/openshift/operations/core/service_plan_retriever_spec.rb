require "topological_inventory/openshift/operations/core/service_plan_retriever"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        RSpec.describe ServicePlanRetriever do
          let(:subject) { described_class.new(123) }

          describe "#process" do
            let(:url) { "http://localhost:3000/api/topological-inventory/v0.0/service_plans/123" }
            let(:headers) { {"Content-Type" => "application/json"} }
            let(:dummy_response) { {"name" => "dummy"} }

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

            it "returns the service plan response" do
              service_plan = subject.process
              expect(service_plan.class).to eq(TopologicalInventoryApiClient::ServicePlan)
              expect(service_plan.name).to eq("dummy")
            end
          end
        end
      end
    end
  end
end
