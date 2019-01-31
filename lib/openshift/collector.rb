require "concurrent"
require "openshift/connection"
require "openshift/parser"
require "topological_inventory-ingress_api-client"

module Openshift
  class Collector
    def initialize(source, openshift_host, openshift_port, openshift_token, default_limit: 100, poll_time: 5)
      self.collector_threads = Concurrent::Map.new
      self.finished          = Concurrent::AtomicBoolean.new(false)
      self.limits            = Hash.new(default_limit)
      self.log               = Logger.new(STDOUT)
      self.openshift_host    = openshift_host
      self.openshift_port    = openshift_port
      self.openshift_token   = openshift_token
      self.poll_time         = poll_time
      self.queue             = Queue.new
      self.source            = source
    end

    def collect!
      start_collector_threads

      until finished? do
        ensure_collector_threads

        notices = []
        notices << queue.pop until queue.empty?

        targeted_refresh(notices) unless notices.empty?

        sleep(poll_time)
      end
    end

    def stop
      finished.value = true
    end

    private

    attr_accessor :collector_threads, :finished, :limits, :log,
                  :openshift_host, :openshift_token, :openshift_port,
                  :poll_time, :queue, :source

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
        collector_thread(connection, entity_type)
      end
    rescue => err
      log.error(err)
      nil
    end

    def collector_thread(connection, entity_type)
      resource_version = full_refresh(connection, entity_type)

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

    def full_refresh(connection, entity_type)
      resource_version = continue = nil

      refresh_state_uuid = SecureRandom.uuid
      log.info("Collecting #{entity_type} with :refresh_state_uuid => '#{refresh_state_uuid}'...")

      total_parts = 0
      loop do
        entities = connection.send("get_#{entity_type}", :limit => limits[entity_type], :continue => continue)
        break if entities.nil?

        continue         = entities.continue
        resource_version = entities.resourceVersion

        parser = Openshift::Parser.new(:openshift_host => openshift_host, :openshift_port => openshift_port)
        parser.send("parse_#{entity_type}", entities)

        refresh_state_part_uuid = SecureRandom.uuid
        total_parts += 1
        save_inventory(parser.collections.values, refresh_state_uuid, refresh_state_part_uuid)

        break if entities.last?
      end

      log.info("Collecting #{entity_type} with :refresh_state_uuid => '#{refresh_state_uuid}'...Complete - Parts [#{total_parts}]")

      log.info("Sweeping inactive records for #{entity_type} with :refresh_state_uuid => '#{refresh_state_uuid}'...")

      parser = Openshift::Parser.new(:openshift_host => openshift_host, :openshift_port => openshift_port)
      collection = parser.send("parse_#{entity_type}", [])

      sweep_inventory(refresh_state_uuid, total_parts, [collection.name])

      log.info("Sweeping inactive records for #{entity_type} with :refresh_state_uuid => '#{refresh_state_uuid}'...Complete")
      resource_version
    rescue => e
      log.error("Error collecting :#{entity_type}, message => #{e.message}")
      raise e
    end

    def targeted_refresh(notices)
      parser = Openshift::Parser.new(:openshift_host => openshift_host, :openshift_port => openshift_port)

      notices.each do |notice|
        entity_type = notice.object&.kind&.underscore
        next if entity_type.nil?

        parse_method = "parse_#{entity_type}_notice"
        parser.send(parse_method, notice)
      end

      save_inventory(parser.collections.values)
    end

    def save_inventory(collections, refresh_state_uuid=nil, refresh_state_part_uuid=nil)
      return if collections.empty?

      ingress_api_client.save_inventory(
        :inventory => TopologicalInventoryIngressApiClient::Inventory.new(
          :name                    => "OCP",
          :schema                  => TopologicalInventoryIngressApiClient::Schema.new(:name => "Default"),
          :source                  => source,
          :collections             => collections,
          :refresh_state_uuid      => refresh_state_uuid,
          :refresh_state_part_uuid => refresh_state_part_uuid,
        )
      )
    end

    def sweep_inventory(refresh_state_uuid, total_parts, sweep_scope)
      ingress_api_client.save_inventory(
        :inventory => TopologicalInventoryIngressApiClient::Inventory.new(
          :name               => "OCP",
          :schema             => TopologicalInventoryIngressApiClient::Schema.new(:name => "Default"),
          :source             => source,
          :collections        => [],
          :refresh_state_uuid => refresh_state_uuid,
          :total_parts        => total_parts,
          :sweep_scope        => sweep_scope,
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
      %w(templates images)
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
      Openshift::Connection.kubernetes(connection_params)
    end

    def openshift_connection
      Openshift::Connection.openshift(connection_params)
    end

    def servicecatalog_connection
      Openshift::Connection.servicecatalog(connection_params)
    end

    def connection_params
      {:host => openshift_host, :port => openshift_port, :token => openshift_token}
    end

    def ingress_api_client
      TopologicalInventoryIngressApiClient::DefaultApi.new
    end
  end
end
