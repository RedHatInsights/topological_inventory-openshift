require "active_support/inflector"
require "more_core_extensions/core_ext/string/iec60027_2"
require "more_core_extensions/core_ext/string/decimal_suffix"
require "openshift/parser/image"
require "openshift/parser/pod"
require "openshift/parser/namespace"
require "openshift/parser/node"
require "openshift/parser/template"
require "openshift/parser/cluster_service_class"
require "openshift/parser/cluster_service_plan"
require "openshift/parser/service_instance"

module Openshift
  class Parser
    include Openshift::Parser::Image
    include Openshift::Parser::Pod
    include Openshift::Parser::Namespace
    include Openshift::Parser::Node
    include Openshift::Parser::Template
    include Openshift::Parser::ClusterServiceClass
    include Openshift::Parser::ClusterServicePlan
    include Openshift::Parser::ServiceInstance

    attr_accessor :collections, :resource_timestamp, :openshift_host, :openshift_port

    def initialize(openshift_host:, openshift_port: 8443 )
      entity_types = [:containers, :container_groups, :container_nodes, :container_projects, :container_images,
                      :container_templates, :service_instances, :service_offerings, :service_plans,
                      :container_group_tags, :container_node_tags, :container_project_tags, :container_image_tags,
                      :container_template_tags, :service_offering_tags, :service_offering_icons]

      self.resource_timestamp = Time.now.utc
      self.collections = entity_types.each_with_object({}).each do |entity_type, collections|
        collections[entity_type] = TopologicalInventoryIngressApiClient::InventoryCollection.new(:name => entity_type, :data => [])
      end
      self.openshift_host = openshift_host
      self.openshift_port = openshift_port
    end

    private

    def parse_base_item(entity)
      {
        :name               => entity.metadata.name,
        :resource_version   => entity.metadata.resourceVersion,
        :resource_timestamp => resource_timestamp,
        :source_created_at  => entity.metadata.creationTimestamp,
        :source_ref         => entity.metadata.uid,
      }
    end

    def archive_entity(inventory_object, entity)
      source_deleted_at = entity.metadata&.deletionTimestamp || Time.now.utc
      inventory_object.source_deleted_at = source_deleted_at
    end

    def lazy_find(collection, reference, ref: :manager_ref)
      TopologicalInventoryIngressApiClient::InventoryObjectLazy.new(
        :inventory_collection_name => collection,
        :reference                 => reference,
        :ref                       => ref,
      )
    end

    def lazy_find_namespace(name)
      return if name.nil?

      TopologicalInventoryIngressApiClient::InventoryObjectLazy.new(
        :inventory_collection_name => :container_projects,
        :reference                 => {:name => name},
        :ref                       => :by_name,
      )
    end

    def lazy_find_node(name)
      return if name.nil?

      TopologicalInventoryIngressApiClient::InventoryObjectLazy.new(
        :inventory_collection_name => :container_nodes,
        :reference                 => {:name => name},
        :ref                       => :by_name,
      )
    end

    def parse_quantity(quantity)
      return if quantity.nil?

      begin
        quantity.iec_60027_2_to_i
      rescue
        quantity.decimal_si_to_f
      end
    end
  end
end
