require "topological_inventory/openshift/operations/processor"

RSpec.describe TopologicalInventory::Openshift::Operations::Processor do
  let(:message) { double("ManageIQ::Messaging::ReceivedMessage", :message => operation_name, :payload => payload) }
  let(:operation_name) { 'Testing.operation' }
  let(:params) { {'source_id' => 1, 'external_tenant' => '12345', 'task_id' => task_id} }
  let(:payload) { {"params" => params, "request_context" => double('request_context')} }
  let(:task_id) { '42' }

  subject { described_class.new(message, nil) }

  describe "#process" do
    context "ServicePlan.order task" do
      let(:svc_plan_class) { TopologicalInventory::Openshift::Operations::ServicePlan }
      let(:operation_name) { 'ServicePlan.order' }

      it "orders service plan" do
        service_plan = svc_plan_class.new(params)
        allow(svc_plan_class).to receive(:new).and_return(service_plan)

        expect(service_plan).to receive(:order)

        subject.process
      end
    end

    context "Source.availability_check task" do
      let(:source_class) { TopologicalInventory::Openshift::Operations::Source }
      let(:operation_name) { 'Source.availability_check' }

      it "runs availability check" do
        source = source_class.new(params)
        allow(source_class).to receive(:new).and_return(source)

        expect(source).to receive(:availability_check)

        subject.process
      end
    end
  end
end
