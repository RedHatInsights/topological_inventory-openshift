#!/usr/bin/env ruby

require "bundler/setup"
require "kubeclient"
require "insights/topological_inventory/client"

source = ENV["SOURCE"]

def ingress_api_client
  @ingress_api_client ||=
    begin
      Insights::TopologicalInventory::Client.configure.host   = "localhost:9292"
      Insights::TopologicalInventory::Client.configure.scheme = "http"
      Insights::TopologicalInventory::Client::AdminsApi.new
    end
end

def kubernetes_connection
  @kubernetes_connection ||=
    begin
      host = ENV["HOST"]
      port = ENV["PORT"] || 8443
      token = ENV["TOKEN"]

      endpoint_opts = {
        :host => host, :port => port
      }

      kubernetes_endpoint_uri = URI::HTTPS.build(endpoint_opts.merge(:path => "/api"))

      api_version = "v1"

      options = {
        :ssl_options => {
          :verify_ssl => OpenSSL::SSL::VERIFY_NONE,
        },
        :auth_options => {
          :bearer_token => token
        }
      }

      Kubeclient::Client.new(kubernetes_endpoint_uri, api_version, options).tap do |conn|
        conn.discover
      end
    end
end

collections = {
  :namespaces => Insights::TopologicalInventory::Client::InventoryCollection.new(:name => "container_projects"),
  :pods       => Insights::TopologicalInventory::Client::InventoryCollection.new(:name => "container_groups"),
}

puts "Collecting namespaces..."
namespaces = kubernetes_connection.get_namespaces
namespaces.each do |namespace|
  collections[:namespaces].data << {
    :name             => namespace.metadata.name,
    :source_ref       => namespace.metadata.uid,
    :resource_version => namespace.metadata.resourceVersion,
    :display_name     => namespace.metadata.annotations["openshift.io/display-name"],
  }
end
puts "Collecting namespaces...Complete - Count [#{namespaces.count}]"

puts "Collecting pods"
pods = kubernetes_connection.get_pods
pods.each do |pod|
  collections[:pods].data << {
    :name             => pod.metadata.name,
    :source_ref       => pod.metadata.uid,
    :resource_version => pod.metadata.resourceVersion,
    :ipaddress        => pod.status.podIP
  }
end
puts "Collecting pods...Complete - Count [#{pods.count}]"

ingress_api_client.save_inventory(
  :inventory => Insights::TopologicalInventory::Client::Inventory.new(
    :name        => "OCP",
    :schema      => Insights::TopologicalInventory::Client::Schema.new(:name => "Default"),
    :source      => source,
    :collections => collections.values,
  )
)
