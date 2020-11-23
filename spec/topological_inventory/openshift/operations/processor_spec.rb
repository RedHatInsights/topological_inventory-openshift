require "topological_inventory/openshift/operations/processor"

RSpec.describe TopologicalInventory::Openshift::Operations::Processor do
  let(:client) { double(:client) }

  context "#process" do
    it "updates task with not_implemented error if operation not supported" do
      # Non-existing class
      task_id = '1'
      processor = described_class.new('SomeModel', 'some_method', {'params' => {'task_id' => task_id}}, nil)
      expect(processor).to receive(:update_task).with(task_id,
                                                      :state   => 'completed',
                                                      :status  => 'error',
                                                      :context => {:error => "SomeModel#some_method not implemented"})
      processor.process

      # Non-existing method
      task_id = '2'
      processor = described_class.new('ServiceCatalogClient', 'some_method', {'params' => {'task_id' => task_id}}, nil)
      expect(processor).to receive(:update_task).with(task_id,
                                                      :state   => 'completed',
                                                      :status  => 'error',
                                                      :context => {:error => "ServiceCatalogClient#some_method not implemented"})
      processor.process
    end
  end
end
