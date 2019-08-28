require "topological_inventory-ingress_api-client/collectors_pool"
require "topological_inventory/openshift/collector"
require "topological_inventory/openshift/logging"

module TopologicalInventory::Openshift
  class CollectorsPool < TopologicalInventoryIngressApiClient::CollectorsPool
    include Logging

    def path_to_config
      File.expand_path("../../../config", File.dirname(__FILE__))
    end

    def path_to_secrets
      File.expand_path("../../../secret", File.dirname(__FILE__))
    end

    def new_collector(source, secret)
      TopologicalInventory::Openshift::Collector.new(source.source, source.host, source.port, secret['password'], metrics)
    end
  end
end
