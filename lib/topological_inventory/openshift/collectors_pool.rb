require "config"
require "topological_inventory/openshift/collector"
require "topological_inventory/openshift/logging"

module TopologicalInventory::Openshift
  class CollectorsPool
    include Logging

    def initialize(config_name, metrics, poll_time: 10)
      self.collectors  = {}
      self.collector_threads = {}
      self.config_name = config_name
      self.metrics     = metrics
      self.poll_time   = poll_time
    end

    def run!
      loop do
        reload_config

        remove_old_collectors
        add_new_collectors

        sleep(poll_time)
      end
    end

    def stop!
      collectors.each_value(&:stop)

      # Wait for end of collectors to ensure metrics are stopped after them
      collector_threads.each { |thread| thread.kill unless thread.join(30) }
    end

    private

    attr_accessor :collectors, :collector_threads, :config_name, :metrics, :poll_time

    def reload_config
      clear_settings

      config_file = File.join(path_to_config, "#{sanitize_filename(config_name)}.yml")
      raise "Configuration file #{config_name} doesn't exist" unless File.exist?(config_file)

      ::Config.load_and_set_settings(config_file)
    end

    def add_new_collectors
      ::Settings.sources.to_a.each do |source|
        if collectors[source.source].nil?
          thread = Thread.new do
            collector = TopologicalInventory::Openshift::Collector.new(source.source, source.host, source.port, source.token, metrics)
            collectors[source] = collector
            collector.collect!
          end
          collector_threads[source.source] = thread
        end
      end
    end

    def remove_old_collectors
      requested_uids = ::Settings.sources.to_a.collect(&:source)
      existing_uids = collectors.keys

      (existing_uids - requested_uids).each do |source_uid|
        collector = collectors.delete(source_uid)
        collector&.stop
        collector_threads.delete(source_uid)
      end
    end

    def clear_settings
      ::Settings.keys.dup.each { |k| ::Settings.delete_field(k) } if defined?(::Settings)
    end

    def path_to_config
      File.expand_path("../../../config", File.dirname(__FILE__))
    end

    def sanitize_filename(filename)
      # Remove any character that aren't 0-9, A-Z, or a-z, / or -
      filename.gsub(/[^0-9A-Z\/\-]/i, '_')
    end
  end
end
