require "topological_inventory/openshift/operations/application_metrics"
require "net/http"

RSpec.describe TopologicalInventory::Openshift::Operations::ApplicationMetrics do
  around do |example|
    WebMock.disable!
    example.run
    WebMock.enable!
  end

  context "Turned on" do
    subject! { described_class.new(9394) }
    after    { subject.stop_server }

    it "exposes metrics" do
      subject.record_error
      subject.record_error

      metrics = get_metrics
      expect(metrics["topological_inventory_openshift_operations_errors_total"]).to eq("2")
    end

    def get_metrics
      metrics = Net::HTTP.get(URI("http://localhost:9394/metrics")).split("\n").delete_if do |e|
        e.blank? || e.start_with?("#")
      end

      metrics.each_with_object({}) do |m, hash|
        k, v = m.split
        hash[k] = v
      end
    end
  end

  context "Turned off" do
    subject! { described_class.new(0) }

    it "doesn't raise exception" do
      expect { subject.record_error }.not_to raise_exception
      expect { subject.stop_server }.not_to raise_exception
    end
  end
end
