require "topological_inventory/openshift/operations/core/service_catalog_client"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        RSpec.describe ServiceCatalogClient do
          let(:subject) { described_class.new("123") }

          let(:auth) { instance_double("Authentication", :password => "token") }

          let(:source_endpoints_retriever) { instance_double("SourceEndpointsRetriever") }
          let(:authentication_retriever) { instance_double("AuthenticationRetriever") }

          let(:endpoints_url) { "http://localhost:3000/api/topological-inventory/v0.0/sources/123/endpoints" }
          let(:endpoints_headers) { {"Content-Type" => "application/json"} }
          let(:endpoints_api_response) do
            {
              "data" => [{
                "default"    => true,
                "id"         => 321,
                "scheme"     => "https",
                "host"       => "example.com",
                "verify_ssl" => verify_ssl
              }]
            }
          end

          before do
            stub_request(:get, endpoints_url).with(:headers => endpoints_headers).to_return(
              :headers => endpoints_headers, :body => endpoints_api_response.to_json
            )
            allow(AuthenticationRetriever).to receive(:new).and_return(authentication_retriever)
            allow(authentication_retriever).to receive(:process).and_return(auth)
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

          describe "#order_service_plan" do
            let(:url) do
              URI.join("https://example.com", "apis/servicecatalog.k8s.io/v1beta1/namespaces/default/serviceinstances").to_s
            end
            let(:external_dummy_response) { {"metadata" => {"selfLink" => "foo"}} }
            let(:headers) do
              {
                "Authorization" => "Bearer token",
                "Content-Type"  => "application/json",
                "Accept"        => "application/json"
              }
            end
            let(:additional_parameters) { {"foo" => "bar", "baz" => "qux"} }
            let(:service_plan_client) { instance_double("ServicePlanClient") }

            before do
              allow(ServicePlanClient).to receive(:new).and_return(service_plan_client)
              allow(service_plan_client).to receive(:build_payload).with(
                "plan_name", "service_offering_name", additional_parameters
              ).and_return("payload")

              stub_request(:post, url).with(:body => "payload", :headers => headers)
              .to_return(:body => external_dummy_response.to_json)
            end

            context "when verify_ssl is true" do
              let(:verify_ssl) { true }

              it "passes the correct verify_ssl option to the http handler" do
                expect(RestClient::Request).to receive(:new).with(hash_including(:verify_ssl => 1)).and_call_original
                subject.order_service_plan("plan_name", "service_offering_name", additional_parameters)
              end

              it "builds the payload" do
                expect(service_plan_client).to receive(:build_payload).with(
                  "plan_name", "service_offering_name", "foo" => "bar", "baz" => "qux"
                )

                subject.order_service_plan("plan_name", "service_offering_name", additional_parameters)
              end

              it "returns the expected response" do
                expect(
                  subject.order_service_plan("plan_name", "service_offering_name", additional_parameters)
                ).to eq(external_dummy_response)
              end
            end

            context "when verify_ssl is false" do
              let(:verify_ssl) { false }

              it "passes the correct verify_ssl option to the http handler" do
                expect(RestClient::Request).to receive(:new).with(hash_including(:verify_ssl => 0)).and_call_original
                subject.order_service_plan("plan_name", "service_offering_name", additional_parameters)
              end

              it "builds the payload" do
                expect(service_plan_client).to receive(:build_payload).with(
                  "plan_name", "service_offering_name", "foo" => "bar", "baz" => "qux"
                )

                subject.order_service_plan("plan_name", "service_offering_name", additional_parameters)
              end

              it "returns the expected response" do
                expect(
                  subject.order_service_plan("plan_name", "service_offering_name", additional_parameters)
                ).to eq(external_dummy_response)
              end
            end
          end
        end
      end
    end
  end
end
