require "sources-api-client"
require "topological_inventory/openshift/operations/source"

RSpec.describe(TopologicalInventory::Openshift::Operations::Source) do
  describe "availability_check" do
    let(:host_url) { "https://cloud.redhat.com" }
    let(:external_tenant) { "11001" }
    let(:identity) do
      { "x-rh-identity" => Base64.encode64({ "identity" => { "account_number" => external_tenant } }.to_json) }
    end
    let(:headers) { {"Content-Type" => "application/json"}.merge(identity) }

    it "makes a patch request to update the availability_status of a source" do
      source_id = "201"
      payload =
        {
          "params" => {
            "source_id"       => source_id,
            "external_tenant" => external_tenant,
            "timestamp"       => Time.now.utc
          }
        }

      stub_request(:get, "https://cloud.redhat.com/api/sources/v1.0/sources/#{source_id}/endpoints")
        .with(:headers => headers)
        .to_return(:status => 200, :body => "", :headers => {})
      stub_request(:patch, "https://cloud.redhat.com/api/sources/v1.0/sources/#{source_id}")
        .with(:body => {"availability_status" => "unavailable"}.to_json, :headers => headers)
        .to_return(:status => 200, :body => "", :headers => {})

      described_class.new(payload["params"]).availability_check
    end
  end
end
