require "topological_inventory-ingress_api-client/collectors_pool"
require "topological_inventory/openshift/collector"
require "topological_inventory/openshift/logging"

module TopologicalInventory::Openshift
  class CollectorsPool < TopologicalInventoryIngressApiClient::CollectorsPool
    include Logging

    def initialize(config_name, metrics, poll_time: 10)
      super
    end

    def path_to_config
      File.expand_path("../../../config", File.dirname(__FILE__))
    end

    def new_collector(source)
      TopologicalInventory::Openshift::Collector.new(source.source, source.host, source.port, source.token, metrics)
    end
  end
end
