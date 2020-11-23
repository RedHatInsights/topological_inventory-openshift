require "topological_inventory/openshift/operations/worker"

RSpec.describe TopologicalInventory::Openshift::Operations::Worker do
  describe "#run" do
    let(:client) { double("ManageIQ::Messaging::Client") }
    let(:message) { double("ManageIQ::Messaging::ReceivedMessage") }
    let(:metrics) { double("Metrics", :record_operation => nil) }
    let(:operation) { 'Test.operation' }
    let(:subject) { described_class.new(metrics) }

    before do
      TopologicalInventory::Openshift::MessagingClient.class_variable_set(:@@default, nil)
      allow(subject).to receive(:client).and_return(client)
      allow(client).to receive(:close)
      allow(TopologicalInventory::Providers::Common::Operations::HealthCheck).to receive(:touch_file)
      allow(message).to receive_messages(:ack => nil, :message => operation)
    end

    it "calls subscribe_topic on the right queue" do
      operations_topic = "platform.topological-inventory.operations-openshift"
      result = double("result")

      expect(client).to(receive(:subscribe_topic)
                          .with(hash_including(:service => operations_topic)).and_yield(message))
      expect(TopologicalInventory::Openshift::Operations::Processor)
        .to receive(:process!).with(message, metrics).and_return(result)

      subject.run
    end

    context ".metrics" do
      it "records successful operation" do
        result = subject.operation_status[:success]

        allow(TopologicalInventory::Openshift::Operations::Processor).to receive(:process!).and_return(result)
        expect(metrics).to receive(:record_operation).with(operation, :status => result)

        subject.send(:process_message, message)
      end

      it "records exception" do
        result = subject.operation_status[:error]

        allow(TopologicalInventory::Openshift::Operations::Processor).to receive(:process!).and_raise("Test Exception!")
        expect(metrics).to receive(:record_operation).with(operation, :status => result)

        subject.send(:process_message, message)
      end
    end
  end
end
