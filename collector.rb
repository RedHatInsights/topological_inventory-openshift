#!/usr/bin/env ruby

require "bundler/setup"
require "optimist"
require "kubeclient"
require "topological_inventory/client"

opts = Optimist::options do
  opt :source, "Inventory Source UID", :type => :string, :required => true
  opt :hostname, "Hostname of the OpenShift master node", :type => :string, :required => true
  opt :port, "Port of the OpenShift API", :type => :int, :default => 8443
  opt :ingress_api, "Hostname of the ingress-api route", :type => :string, :default => "localhost:9292"
  opt :token, "Auth token to the OpenShift cluster", :type => :string
end

opts[:token] ||= ENV["OPENSHIFT_AUTH_TOKEN"]
if opts[:token].nil?
  puts "Error: option --token or OPENSHIFT_AUTH_TOKEN env var must be specified."
  exit 1
end

TopologicalInventory::Client.configure.host   = opts[:ingress_api]
TopologicalInventory::Client.configure.scheme = "http"

def ingress_api_client
  @ingress_api_client ||= TopologicalInventory::Client::AdminsApi.new
end

def kubernetes_connection(host, port, token)
  @kubernetes_connection ||=
    begin
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
  :namespaces => TopologicalInventory::Client::InventoryCollection.new(:name => "container_projects"),
  :pods       => TopologicalInventory::Client::InventoryCollection.new(:name => "container_groups"),
}

puts "Collecting namespaces..."
connection = kubernetes_connection(opts[:hostname], opts[:port], opts[:token])

namespaces = connection.get_namespaces
namespaces.each do |namespace|
  collections[:namespaces].data << TopologicalInventory::Client::ContainerProject.new(
    :name             => namespace.metadata.name,
    :source_ref       => namespace.metadata.uid,
    :resource_version => namespace.metadata.resourceVersion,
    :display_name     => namespace.metadata.annotations["openshift.io/display-name"],
  )
end
puts "Collecting namespaces...Complete - Count [#{namespaces.count}]"

puts "Collecting pods"
pods = connection.get_pods
pods.each do |pod|
  collections[:pods].data << TopologicalInventory::Client::ContainerGroup.new(
    :name              => pod.metadata.name,
    :source_ref        => pod.metadata.uid,
    :resource_version  => pod.metadata.resourceVersion,
    :ipaddress         => pod.status.podIP,
    :container_project => TopologicalInventory::Client::InventoryObjectLazy.new(
      :inventory_collection_name => :container_projects,
      :reference                 => {:name => pod.metadata.namespace},
      :ref                       => :by_name,
    )
  )
end
puts "Collecting pods...Complete - Count [#{pods.count}]"

ingress_api_client.save_inventory(
  :inventory => TopologicalInventory::Client::Inventory.new(
    :name        => "OCP",
    :schema      => TopologicalInventory::Client::Schema.new(:name => "Default"),
    :source      => opts[:source],
    :collections => collections.values,
  )
)
