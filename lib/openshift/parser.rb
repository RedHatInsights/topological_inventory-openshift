require "active_support/inflector"
require "openshift/parser/pod"
require "openshift/parser/namespace"
require "openshift/parser/template"
require "openshift/parser/cluster_service_class"
require "openshift/parser/cluster_service_plan"
require "openshift/parser/service_instance"

module Openshift
  class Parser
    include Openshift::Parser::Pod
    include Openshift::Parser::Namespace
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
        :container_project => namespace_lazy_ref(entity),
      }
    end

    def namespace_lazy_ref(entity)
      TopologicalInventory::IngressApi::Client::InventoryObjectLazy.new(
        :inventory_collection_name => :container_projects,
        :reference                 => {:name => entity.metadata&.namespace},
        :ref                       => :by_name,
      )
    end
  end
end
