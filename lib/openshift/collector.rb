require "concurrent"
require "openshift/connection"
require "openshift/parser"
require "topological_inventory/ingress_api/client"

module Openshift
  class Collector
    def initialize(source, openshift_host, openshift_token)
      self.collector_threads = Concurrent::Map.new
      self.finished          = Concurrent::AtomicBoolean.new(false)
      self.log               = Logger.new(STDOUT)
      self.openshift_host    = openshift_host
      self.openshift_token   = openshift_token
      self.queue             = Queue.new
      self.resource_versions = Concurrent::Map.new
      self.source            = source
    end

    def collect!
      full_refresh

      start_collector_threads

      until finished? do
        ensure_collector_threads

        notices = []
        notices << queue.pop until queue.empty?

        targeted_refresh(notices) unless notices.empty?
      end
    end

    def stop
      finished.value = true
    end

    private

    attr_accessor :collector_threads, :finished, :log, :openshift_host, :openshift_token, :queue, :resource_versions, :source

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

      Thread.new do
        collector_thread(connection, entity_type, resource_versions[entity_type])
      end
    rescue => err
      log.error(err)
      nil
    end

    def collector_thread(connection, entity_type, resource_version)
      resource_version ||= "0"
      watch(connection, entity_type, resource_version) do |notice|
        log.info("#{entity_type} #{notice.object.metadata.name} was #{notice.type.downcase}")
        queue.push(notice)
      end
    rescue => err
      log.error(err)
    end

    def watch(connection, entity_type, resource_version)
      connection.send("watch_#{entity_type}", :resource_version => resource_version).each { |notice| yield notice }
    end

    def full_refresh
      parser = Openshift::Parser.new

      entity_types.each do |entity_type|
        entities = connection_for_entity_type(entity_type).send("get_#{entity_type}")
        next if entities.nil?

        log.info("Retrieved #{entities.count} #{entity_type}...")

        resource_versions[entity_type] = entities.resourceVersion

        parser.send("parse_#{entity_type}", entities)
      end

      save_inventory(parser.collections.values)
    end

    def targeted_refresh(notices)
      parser = Openshift::Parser.new

      notices.each do |notice|
        entity_type = notice.object&.kind&.underscore
        next if entity_type.nil?

        parse_method = "parse_#{entity_type}_notice"
        parser.send(parse_method, notice)
      end

      save_inventory(parser.collections.values)
    end

    def save_inventory(collections)
      return if collections.empty?

      ingress_api_client.save_inventory(
        :inventory => TopologicalInventory::IngressApi::Client::Inventory.new(
          :name        => "OCP",
          :schema      => TopologicalInventory::IngressApi::Client::Schema.new(:name => "Default"),
          :source      => source,
          :collections => collections,
        )
      )
    end

    def entity_types
      endpoint_types.flat_map { |endpoint| send("#{endpoint}_entity_types") }
    end

    def kubernetes_entity_types
      %w(namespaces pods nodes)
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
      TopologicalInventory::IngressApi::Client::AdminsApi.new
    end
  end
end
