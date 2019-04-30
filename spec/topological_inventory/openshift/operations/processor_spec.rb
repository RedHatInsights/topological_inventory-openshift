require "topological_inventory/openshift/operations/processor"

RSpec.describe TopologicalInventory::Openshift::Operations::Processor do
  let(:client) { double(:client) }

  describe "#order_service (private)" do
    let(:task) { double("Task", :id => 1) }

    let(:service_plan) do
      TopologicalInventoryApiClient::ServicePlan.new(:id                  => "123",
                                                     :name                => "plan_name",
                                                     :source_id           => source.id,
                                                     :service_offering_id => service_offering.id)
    end
    let(:source) do
      TopologicalInventoryApiClient::Source.new(:id => "321")
    end
    let(:service_offering) do
      TopologicalInventoryApiClient::ServiceOffering.new(:id => "456", :name => "service_offering", :source_id => source.id)
    end

    let(:service_instance) do
      TopologicalInventoryApiClient::ServiceInstance.new(:id => "789", :name => "service_instance", :source_ref => "af01c63c-e479-4190-8054-9c5ba2e9ec81")
    end

    let(:identity) { {"x-rh-identity"=>"eyJpZGVudGl0eSI6eyJhY2NvdW50X251bWJlciI6IjI0MCJ9fQ==\n"} }

    let(:payload) do
      {
        "request_context" => identity,
        "params"          => {
          "service_plan_id" => service_plan.id.to_s,
          "order_params"    => "order_params",
          "task_id"         => task.id.to_s,
        }
      }
    end

    let(:service_catalog_client) { instance_double("ServiceCatalogClient") }
    let(:base_url_path) { "https://cloud.redhat.com/api/topological-inventory/v1.0/" }
    let(:service_plan_url) { URI.join(base_url_path, "service_plans/#{service_plan.id}").to_s }
    let(:source_url) { URI.join(base_url_path, "sources/#{source.id}").to_s }
    let(:service_offering_url) { URI.join(base_url_path, "service_offerings/#{service_offering.id}").to_s }
    let(:service_instances_url) { URI.join(base_url_path, "service_instances?source_id=#{source.id}&source_ref=#{service_instance.source_ref}") }
    let(:task_url) { URI.join(base_url_path, "tasks/#{task.id}").to_s }
    let(:headers) { {"Content-Type" => "application/json", "x-rh-identity"=>"eyJpZGVudGl0eSI6eyJhY2NvdW50X251bWJlciI6IjI0MCJ9fQ==\n"} }
    let(:reason) { "ProvisionedSuccessfully" }
    let(:message) { "Message" }
    let(:service_instance) do
      Kubeclient::Resource.new(
        :metadata => {
          :name      => "my_service",
          :namespace => "default",
          :uid       => "af01c63c-e479-4190-8054-9c5ba2e9ec81"
        },
        :status   => {
          :conditions => [
            Kubeclient::Resource.new(
              :reason => "ProvisionedSuccessfully"
            )
          ]
        },
        :id       => 123
      )
    end

    before do
      require "active_support/json"
      require "active_support/core_ext/object/json" # required to get service_plan.to_json to work properly

      stub_request(:get, service_plan_url).with(:headers => headers).to_return(
        :headers => headers, :body => service_plan.to_json
      )
      stub_request(:get, source_url).with(:headers => headers).to_return(
        :headers => headers, :body => source.to_json
      )
      stub_request(:get, service_offering_url).with(:headers => headers).to_return(
        :headers => headers, :body => service_offering.to_json
      )
      stub_request(:get, service_instances_url).with(:headers => headers).to_return(
        :headers => headers, :body => {:meta => {:count => 1}, :data => [service_instance.to_hash]}.to_json
      )

      allow(
        TopologicalInventory::Openshift::Operations::Core::ServiceCatalogClient
      ).to receive(:new).with(source.id, identity).and_return(service_catalog_client)

      allow(service_catalog_client).to receive(:order_service_plan).and_return(service_instance)
      allow(service_catalog_client).to receive(:wait_for_provision_complete).and_return([service_instance, reason, message])

      stub_request(:patch, task_url).with(:headers => headers)
    end

    it "orders the service via the service catalog client" do
      expect(service_catalog_client).to receive(:order_service_plan).with("plan_name", "service_offering", "order_params")
      expect(service_catalog_client).to receive(:wait_for_provision_complete).with(service_instance.metadata.name, service_instance.metadata.namespace)
      thread = described_class.new("ServicePlan", "order", payload).process
      thread.join
    end

    it "makes a patch request to the update task endpoint with the status and context" do
      expected_context = {
        :service_instance => {
          :source_id         => source.id,
          :source_ref        => service_instance.source_ref,
          :provision_state   => reason,
          :provision_message => message,
          :id                => service_instance.id.to_s,
          :url               => "#{base_url_path}service_instances/#{service_instance.id}"
        }
      }.to_json

      thread = described_class.new("ServicePlan", "order", payload).process
      thread.join

      expect(
        a_request(:patch, task_url).with(:body => {"status" => "ok", "state" => "completed", "context" => expected_context})
      ).to have_been_made
    end
  end
end
