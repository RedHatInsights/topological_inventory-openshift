require "topological_inventory/openshift/operations/worker"
require "topological_inventory/openshift/operations/application_metrics"

RSpec.describe TopologicalInventory::Openshift::Operations::Worker do
  describe "#run" do
    let(:client)  { double("ManageIQ::Messaging::Client") }
    let(:metrics) { double }
    let(:subject) { described_class.new(metrics) }
    let(:message) { double }
    before do
      allow(ManageIQ::Messaging::Client).to receive(:open).and_return(client)
      allow(client).to receive(:close)
      allow(subject).to receive(:logger).and_return(double('null_object').as_null_object)
    end

    context "when connecting to the queue happens successfully" do
      it "calls subscribe_messages on the right queue" do
        operations_topic = "platform.topological-inventory.operations-openshift"
        expect(client).to receive(:subscribe_topic)
          .with(hash_including(:service => operations_topic))
        subject.run
      end
    end

    context "when processing a message fails" do
      before do
        allow(client).to receive(:subscribe_topic).and_yield(message)
        allow(client).to receive(:ack)
        allow(message).to receive(:message).and_raise(StandardError)
        allow(message).to receive(:ack_ref)
      end

      it "records metrics on failure" do
        expect(metrics).to receive(:record_error)
        subject.run
      end
    end
  end
end
