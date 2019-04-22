require "topological_inventory/openshift/operations/core/authentication_retriever"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        RSpec.describe AuthenticationRetriever do
          let(:subject) { described_class.new(123) }

          let(:headers) { {"Content-Type" => "application/json"} }
          let(:internal_authentications_url) do
            "https://cloud.redhat.com/internal/v1.0/authentications/123?expose_encrypted_attribute[]=password"
          end
          let(:internal_authentication_response) { {"password" => "token"} }

          before do
            stub_request(:get, internal_authentications_url).with(:headers => headers).to_return(
              :headers => headers, :body => internal_authentication_response.to_json
            )
          end

          describe "#process" do
            it "returns the relevant authentication" do
              authentication = subject.process
              expect(authentication.class).to eq(SourcesApiClient::Authentication)
              expect(authentication.password).to eq("token")
            end
          end
        end
      end
    end
  end
end
