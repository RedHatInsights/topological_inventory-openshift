require "prometheus_exporter"
require "prometheus_exporter/server"
require "prometheus_exporter/client"
require 'prometheus_exporter/instrumentation'

module TopologicalInventory::Openshift
  class Collector
    class Metrics
      def initialize(port = 9394)
        configure_server(port)
        configure_metrics
      end

      def record_error
        @errors_counter.observe(1)
      end

      def stop_server
        @server.stop
      end

      private

      def configure_server(port)
        @server = PrometheusExporter::Server::WebServer.new(:port => port)
        @server.start

        PrometheusExporter::Client.default = PrometheusExporter::LocalClient.new(:collector => @server.collector)
      end

      def configure_metrics
        PrometheusExporter::Instrumentation::Process.start

        PrometheusExporter::Metric::Base.default_prefix = "topological_inventory_openshift_collector_"

        @errors_counter = PrometheusExporter::Metric::Counter.new("errors_total", "total number of collector errors")
        @server.collector.register_metric(@errors_counter)
      end
    end
  end
end
