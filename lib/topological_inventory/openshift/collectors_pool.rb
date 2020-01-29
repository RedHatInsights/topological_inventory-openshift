require "topological_inventory/providers/common/collectors_pool"
require "topological_inventory/openshift/collector"
require "topological_inventory/openshift/logging"

module TopologicalInventory::Openshift
  # Collector pool for openshift cannot interrupt collector due to watches at this moment
  # So there can't be queue with FixedThreadPool
  # !!!
  # *IMPORTANT* doesn't have constant memory usage with increasing number of sources
  # !!!
  class CollectorsPool < TopologicalInventory::Providers::Common::CollectorsPool
    include Logging

    def initialize(config_name, metrics)
      super
      self.collectors  = {}
      self.thread_pool = Concurrent::CachedThreadPool.new
    end

    def run!
      loop do
        reload_config
        reload_secrets

        # Secret is deployed just after config,
        # so we should wait for it
        if secrets_newer_than_config?
          remove_old_collectors
          add_new_collectors
        end

        sleep(10)
      end
    end

    protected

    def add_new_collectors
      ::Settings.sources.to_a.each do |source|
        next unless collectors[source.source].nil?
        next if (source_secret = secrets_for_source(source)).nil?

        # Check if necessary endpoint/auth data are not blank (provider specific)
        next unless source_valid?(source, source_secret)

        collector = new_collector(source, source_secret)
        collectors[source.source] = collector

        thread_pool.post do
          collector.collect!
        end
      end
    end

    def remove_old_collectors
      requested_uids = ::Settings.sources.to_a.collect(&:source)
      existing_uids  = collectors.keys

      (existing_uids - requested_uids).each do |source_uid|
        collector = collectors.delete(source_uid)
        collector&.stop
      end
    end

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
