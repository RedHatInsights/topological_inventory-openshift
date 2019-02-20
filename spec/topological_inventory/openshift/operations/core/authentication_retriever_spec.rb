require "topological_inventory/openshift/operations/core/authentication_retriever"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        RSpec.describe AuthenticationRetriever do
          let(:subject) { described_class.new(123) }

          let(:headers) { {"Content-Type" => "application/json"} }
          let(:endpoint_authentications_url) do
            "http://localhost:3000/api/topological-inventory/v0.0/endpoints/123/authentications"
          end
          let(:internal_authentications_url) do
            "http://localhost:3000/internal/v0.0/authentications/321?expose_encrypted_attribute[]=password"
          end
          let(:endpoints_authentications_response) do
            {
              "data" => [{
                "id" => 321
              }]
            }
          end
          let(:internal_authentication_response) { {"password" => "token"} }

          before do
            stub_request(:get, endpoint_authentications_url).with(:headers => headers).to_return(
              :headers => headers, :body => endpoints_authentications_response.to_json
            )
            stub_request(:get, internal_authentications_url).with(:headers => headers).to_return(
              :headers => headers, :body => internal_authentication_response.to_json
            )
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

          describe "#process" do
            it "returns the relevant authentication" do
              authentication = subject.process
              expect(authentication.class).to eq(TopologicalInventoryApiClient::Authentication)
              expect(authentication.password).to eq("token")
            end
          end
        end
      end
    end
  end
end
