require "concurrent"
require "topological_inventory-ingress_api-client/collector"
require "topological_inventory/openshift"
require "topological_inventory/openshift/logging"
require "topological_inventory/openshift/connection"
require "topological_inventory/openshift/parser"
require "topological_inventory-ingress_api-client"
require "topological_inventory-ingress_api-client/save_inventory/saver"

module TopologicalInventory::Openshift
  class Collector < TopologicalInventoryIngressApiClient::Collector
    include Logging

    def initialize(source, openshift_host, openshift_port, openshift_token, metrics, default_limit: 500, poll_time: 30)
      super(source,
            :default_limit => default_limit,
            :poll_time     => poll_time)

      self.connection_manager = Connection.new
      self.metrics           = metrics
      self.openshift_host    = openshift_host
      self.openshift_port    = openshift_port
      self.openshift_token   = openshift_token
    end

    def collect!
      start_collector_threads

      errors = 0
      until finished?
        ensure_collector_threads

        notices = []
        notices << queue.pop until queue.empty?

        begin
          targeted_refresh(notices) unless notices.empty?

          errors = 0
          sleep(poll_time)
        rescue => err
          metrics.record_error
          logger.error(err)

          errors += 1 unless errors > 10
          sleep(poll_time * errors)
        end
      end
    end

    private

    attr_accessor :connection_manager,
                  :metrics, :openshift_host, :openshift_token, :openshift_port


    def start_collector_thread(entity_type)
      logger.info("Starting collector thread for #{entity_type}...")

      super
    rescue Kubeclient::ResourceNotFoundError => err
      logger.warn("Entity type '#{entity_type}' not found: #{err}")
      nil
    rescue StandardError => err
      logger.error("Error collecting entity type '#{entity_type}': #{err}")
      logger.error(err)
      nil
    end

    def collector_thread(connection, entity_type)
      resource_version = full_refresh(connection, entity_type)

      watch(connection, entity_type, resource_version) do |notice|
        logger.info("#{entity_type} #{notice.object.metadata.name} was #{notice.type.downcase}")
        queue.push(notice)
      end
    rescue StandardError => err
      logger.error("Error collecting entity type '#{entity_type}': #{err}")
      logger.error(err)
    end

    def watch(connection, entity_type, resource_version)
      connection.send("watch_#{entity_type}", :resource_version => resource_version).each { |notice| yield notice }
    end

    def full_refresh(connection, entity_type)
      resource_version = continue = nil

      refresh_state_uuid = SecureRandom.uuid
      logger.info("Collecting #{entity_type} with :refresh_state_uuid => '#{refresh_state_uuid}'...")

      total_parts = 0
      sweep_scope = Set.new
      loop do
        entities = connection.send("get_#{entity_type}", :limit => limits[entity_type], :continue => continue)
        break if entities.nil?

        continue         = entities.continue
        resource_version = entities.resourceVersion

        parser = Parser.new(:openshift_host => openshift_host, :openshift_port => openshift_port)
        parser.send("parse_#{entity_type}", entities)

        refresh_state_part_uuid = SecureRandom.uuid
        total_parts += save_inventory(parser.collections.values, inventory_name, schema_name, refresh_state_uuid, refresh_state_part_uuid)
        sweep_scope.merge(parser.collections.values.map(&:name))

        break if entities.last?
      end

      logger.info("Collecting #{entity_type} with :refresh_state_uuid => '#{refresh_state_uuid}'...Complete - Parts [#{total_parts}]")

      sweep_scope = sweep_scope.to_a
      logger.info("Sweeping inactive records for #{sweep_scope} with :refresh_state_uuid => '#{refresh_state_uuid}'...")

      sweep_inventory(inventory_name, schema_name, refresh_state_uuid, total_parts, sweep_scope)

      logger.info("Sweeping inactive records for #{sweep_scope} with :refresh_state_uuid => '#{refresh_state_uuid}'...Complete")
      resource_version
    end

    def targeted_refresh(notices)
      parser = Parser.new(:openshift_host => openshift_host, :openshift_port => openshift_port)

      notices.each do |notice|
        entity_type = notice.object&.kind&.underscore
        next if entity_type.nil?

        parse_method = "parse_#{entity_type}_notice"
        parser.send(parse_method, notice)
      end

      refresh_state_uuid      = SecureRandom.uuid
      refresh_state_part_uuid = SecureRandom.uuid
      total_parts = save_inventory(parser.collections.values, inventory_name, schema_name, refresh_state_uuid, refresh_state_part_uuid)

      sweep_inventory(inventory_name, schema_name, refresh_state_uuid, total_parts, parse_targeted_sweep_scope(parser.collections.values))
    end

    def parse_targeted_sweep_scope(collections)
      sweep_scope = {}
      collections.each do |collection|
        if (parent_keys = targeted_sweep_scopes[collection.name])
          # Calling to_set.to_a filters it to only unique lazy_finds
          sweep_scope[collection.name] = collection.data.map { |x| x.to_hash.slice(*parent_keys) }.to_set.to_a
        end
      end

      sweep_scope
    end

    def targeted_sweep_scopes
      # Set attribute names that are determining the scope of the subcollections
      # e.g. for containers it's container_group attribute, which is a lazy find to container group. So we collect all
      # container_groups of the saved containers and we take them as a scope. That means containers of those
      # container groups that no longer exist, will be sweeped.
      @targeted_sweep_scopes ||= {
        :container_image_tags    => [:container_image],
        :containers              => [:container_group],
        :container_group_tags    => [:container_group],
        :container_project_tags  => [:container_project],
        :container_node_tags     => [:container_node],
        :container_template_tags => [:container_template],
        :service_offering_tags   => [:container_offering],
        :service_offering_icons  => [:container_offering],
      }
    end

    def kubernetes_entity_types
      %w[namespaces pods nodes resource_quotas]
    end

    def openshift_entity_types
      %w[templates images]
    end

    def servicecatalog_entity_types
      %w[cluster_service_classes cluster_service_plans service_instances]
    end

    def endpoint_types
      %w[kubernetes openshift servicecatalog]
    end

    def connection_for_entity_type(entity_type)
      endpoint_type = endpoint_for_entity_type(entity_type)
      return if endpoint_type.nil?

      connection_manager.connect(endpoint_type, connection_params)
    end

    def endpoint_for_entity_type(entity_type)
      endpoint_types.each do |endpoint|
        return endpoint if send("#{endpoint}_entity_types").include?(entity_type)
      end

      nil
    end

    def connection_params
      {:host => openshift_host, :port => openshift_port, :token => openshift_token}
    end

    # Used for Save & Sweep Inventory
    def inventory_name
      "OCP"
    end

    def ingress_api_client
      TopologicalInventoryIngressApiClient::DefaultApi.new
    end
  end
end
