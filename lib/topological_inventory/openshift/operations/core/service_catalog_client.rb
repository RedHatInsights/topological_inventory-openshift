require 'more_core_extensions/core_ext/hash'
require "topological_inventory/openshift/logging"
require "topological_inventory/openshift/connection"
require "topological_inventory/openshift/operations/core/authentication_retriever"
require "topological_inventory-api-client"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        class ServiceCatalogClient
          include Logging

          attr_accessor :connection_manager, :sleep_poll, :source_id, :identity

          def initialize(source_id, identity = nil)
            self.sleep_poll = 10
            self.identity   = identity
            self.source_id  = source_id

            self.connection_manager = TopologicalInventory::Openshift::Connection.new
          end

          def sources_api_client
            @sources_api_client ||= begin
              api_client = SourcesApiClient::ApiClient.new
              api_client.default_headers.merge!(identity) if identity.present?
              SourcesApiClient::DefaultApi.new(api_client)
            end
          end

          def order_service_plan(plan_name, service_offering_name, additional_parameters)
            payload = build_payload(plan_name, service_offering_name, additional_parameters)
            connection.create_service_instance(payload)
          end

          def wait_for_provision_complete(name, namespace)
            service_instance = nil

            loop do
              sleep(sleep_poll)

              service_instance = connection.get_service_instance(name, namespace)

              condition = service_instance.status.conditions.first
              logger.info("#{service_instance.metadata.name}: message [#{condition&.message}] status [#{condition&.status}] reason [#{condition&.reason}]")

              break unless service_instance_provisioning?(service_instance)
            end

            service_instance
          end

          def authentication
            @authentication ||= fetch_authentication
          end

          def default_endpoint
            @default_endpoint ||= fetch_default_endpoint
          end

          private

          def build_payload(service_plan_name, service_offering_name, order_parameters)
            # We need to not send empty strings in case the parameter is generated
            # More details are explained in the comment in the OpenShift web catalog
            # https://github.com/openshift/origin-web-catalog/blob/4c5cb3ee1ae0061ed28fc6190a0f8fff71771122/src/components/order-service/order-service.controller.ts#L442
            safe_params = order_parameters["service_parameters"].delete_blanks

            {
              :metadata => {
                :name      => "#{service_offering_name}-#{SecureRandom.uuid}",
                :namespace => order_parameters["provider_control_parameters"]["namespace"]
              },
              :spec     => {
                :clusterServiceClassExternalName => service_offering_name,
                :clusterServicePlanExternalName  => service_plan_name,
                :parameters                      => safe_params
              }
            }
          end

          def service_instance_provisioning?(service_instance)
            reason = service_instance.status.conditions.first&.reason
            %w[Provisioning ProvisionRequestInFlight].include?(reason)
          end

          def connection
            Thread.current[:kubernetes_connection] ||= begin
              raise "Unable to find a default endpoint for source [#{source_id}]" if default_endpoint.nil?
              raise "Unable to find an authentication for source [#{source_id}]"  if authentication.nil?

              connection_manager.connect("servicecatalog", :host => default_endpoint.host, :token => authentication.password, :verify_ssl => verify_ssl_mode)
            end
          end

          def verify_ssl_mode
            default_endpoint.verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
          end

          def fetch_default_endpoint
            endpoints = sources_api_client.list_source_endpoints(source_id)&.data || []
            endpoints.find(&:default)
          end

          def fetch_authentication
            endpoint = default_endpoint
            return if endpoint.nil?

            endpoint_authentications = sources_api_client.list_endpoint_authentications(endpoint.id.to_s).data || []
            return if endpoint_authentications.empty?

            auth_id = endpoint_authentications.first.id
            AuthenticationRetriever.new(auth_id, identity).process
          end
        end
      end
    end
  end
end
