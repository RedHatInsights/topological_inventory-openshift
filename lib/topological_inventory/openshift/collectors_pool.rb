require "topological_inventory/providers/common/collectors_pool"
require "topological_inventory/openshift/collector"
require "topological_inventory/openshift/logging"

module TopologicalInventory::Openshift
  class CollectorsPool < TopologicalInventory::Providers::Common::CollectorsPool
    include Logging

    def path_to_config
      File.expand_path("../../../config", File.dirname(__FILE__))
    end

    def path_to_secrets
      File.expand_path("../../../secret", File.dirname(__FILE__))
    end

    def source_valid?(source, secret)
      missing_data = [source.source,
                      source.host,
                      secret["password"]].select do |data|
        data.to_s.strip.blank?
      end
      missing_data.empty?
    end

    def new_collector(source, secret)
      TopologicalInventory::Openshift::Collector.new(source.source, source.host, source.port, secret['password'], metrics)
    end
  end
end
