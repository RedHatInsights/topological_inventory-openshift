require "active_support/inflector"
require "openshift/parser/pod"
require "openshift/parser/namespace"
require "openshift/parser/node"
require "openshift/parser/template"
require "openshift/parser/cluster_service_class"
require "openshift/parser/cluster_service_plan"
require "openshift/parser/service_instance"

module Openshift
  class Parser
    include Openshift::Parser::Pod
    include Openshift::Parser::Namespace
    include Openshift::Parser::Node
    include Openshift::Parser::Template
    include Openshift::Parser::ClusterServiceClass
    include Openshift::Parser::ClusterServicePlan
    include Openshift::Parser::ServiceInstance

    attr_accessor :collections

    def initialize
      self.collections = {}
    end

    private

    def collection
      collections[inventory_collection_name] ||=
        TopologicalInventory::IngressApi::Client::InventoryCollection.new(:name => inventory_collection_name)
    end

    def parse_base_item(entity)
      {
        :name              => entity.metadata.name,
        :source_ref        => entity.metadata.uid,
        :resource_version  => entity.metadata.resourceVersion,
        :container_project => lazy_find_namespace(entity.metadata&.namespace),
      }
    end

    def lazy_find_namespace(name)
      return if name.nil?

      TopologicalInventory::IngressApi::Client::InventoryObjectLazy.new(
        :inventory_collection_name => :container_projects,
        :reference                 => {:name => name},
        :ref                       => :by_name,
      )
    end

    def lazy_find_node(name)
      return if name.nil?

      TopologicalInventory::IngressApi::Client::InventoryObjectLazy.new(
        :inventory_collection_name => :container_nodes,
        :reference                 => {:name => name},
        :ref                       => :by_name,
      )
    end
  end
end
