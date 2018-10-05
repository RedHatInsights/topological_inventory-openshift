require "concurrent"
require "openshift/connection"
require "openshift/parser"
require "topological_inventory/client"

module Openshift
  class Collector
    def initialize(source, openshift_host, openshift_token)
      self.collector_threads = {}
      self.finished          = Concurrent::AtomicBoolean.new(false)
      self.log               = Logger.new(STDOUT)
      self.openshift_host    = openshift_host
      self.openshift_token   = openshift_token
      self.source            = source
    end

    def collect!
      start_collector_threads

      until finished? do
        sleep 10
        ensure_collector_threads
      end
    end

    def stop
      finished.value = true
    end

    private

    attr_accessor :collector_threads, :finished, :log, :openshift_host, :openshift_token, :source

    def finished?
      finished.value
    end

    def ensure_collector_threads
      entity_types.each do |entity_type|
        next if collector_threads[entity_type] && collector_threads[entity_type].alive?

        collector_threads[entity_type] = start_collector_thread(entity_type)
      end
    end
    alias start_collector_threads ensure_collector_threads

    def start_collector_thread(entity_type)
      log.info("Starting collector thread for #{entity_type}...")
      connection = connection_for_entity_type(entity_type)
      Thread.new { collector_thread(connection, entity_type) }
    rescue => err
      log.error(err)
      nil
    end

    def collector_thread(connection, entity_type)
      parser_klass = Openshift::Parser.parser_klass_for(entity_type)

      full_collection = connection.send("get_#{entity_type}")
      return if full_collection.nil?

      resource_version = full_collection.resourceVersion

      log.info("Retrieved #{full_collection.count} #{entity_type}...")

      parser = parser_klass.new
      parser.parse(full_collection)
      collections = parser.collections

      ingress_api_client.save_inventory(
        :inventory => TopologicalInventory::Client::Inventory.new(
          :name        => "OCP",
          :schema      => TopologicalInventory::Client::Schema.new(:name => "Default"),
          :source      => source,
          :collections => collections.values,
        )
      )

      connection.send("watch_#{entity_type}", :resource_version => resource_version).each do |notice|
        log.info("Caught a #{entity_type} watch notice for #{notice.object.metadata.name}")
        parser.parse_notice(notice)
      end
    rescue => err
      log.error(err)
    end

    def entity_types
      endpoint_types.flat_map { |endpoint| send("#{endpoint}_entity_types") }
    end

    def kubernetes_entity_types
      %w(namespaces pods)
    end

    def openshift_entity_types
      %w()
    end

    def servicecatalog_entity_types
      %w(cluster_service_classes cluster_service_plans service_instances)
    end

    def endpoint_types
      %w(kubernetes openshift servicecatalog)
    end

    def connection_for_entity_type(entity_type)
      endpoint_types.each do |endpoint|
        return send("#{endpoint}_connection") if send("#{endpoint}_entity_types").include?(entity_type)
      end
      return nil
    end

    def kubernetes_connection
      Openshift::Connection.kubernetes(host: openshift_host, token: openshift_token)
    end

    def openshift_connection
      Openshift::Connection.openshift(host: openshift_host, token: openshift_token)
    end

    def servicecatalog_connection
      Openshift::Connection.servicecatalog(host: openshift_host, token: openshift_token)
    end

    def ingress_api_client
      TopologicalInventory::Client::AdminsApi.new
    end
  end
end
