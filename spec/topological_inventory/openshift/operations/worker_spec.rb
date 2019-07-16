require "topological_inventory/openshift/operations/worker"
require "topological_inventory/openshift/operations/application_metrics"

RSpec.describe TopologicalInventory::Openshift::Operations::Worker do
  describe "#run" do
    let(:client)  { double("ManageIQ::Messaging::Client") }
    let(:metrics) { TopologicalInventory::Openshift::Operations::ApplicationMetrics.new(0) }
    let(:subject) { described_class.new(metrics) }
    before do
      allow(ManageIQ::Messaging::Client).to receive(:open).and_return(client)
      allow(client).to receive(:close)
      allow(subject).to receive(:logger).and_return(double('null_object').as_null_object)
    end

    it "calls subscribe_messages on the right queue" do
      operations_topic = "platform.topological-inventory.operations-openshift"
      expect(client).to receive(:subscribe_topic)
        .with(hash_including(:service => operations_topic))
      subject.run
    end
  end
end
