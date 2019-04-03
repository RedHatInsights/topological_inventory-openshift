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

          attr_accessor :default_endpoint, :authentication, :connection_manager, :sleep_poll, :identity

          def initialize(source_id, identity = nil)
            self.sleep_poll = 10
            self.identity = identity

            all_source_endpoints = api_client.list_source_endpoints(source_id)
            self.default_endpoint = all_source_endpoints.data.find(&:default)

            authentication_id = api_client.list_endpoint_authentications(default_endpoint.id.to_s).data.first&.id
            self.authentication = AuthenticationRetriever.new(authentication_id, identity).process

            self.connection_manager = TopologicalInventory::Openshift::Connection.new
          end

          def api_client
            @api_client ||=
              begin
                TopologicalInventoryApiClient::DefaultApi.new(
                  TopologicalInventoryApiClient::ApiClient.new.tap do |api|
                    api.default_headers.merge!(identity) if identity.present?
                  end
                )
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
            Thread.current[:kubernetes_connection] ||= connection_manager.connect(
              "servicecatalog", :host => default_endpoint.host, :token => authentication.password, :verify_ssl => verify_ssl_mode
            )
          end

          def verify_ssl_mode
            default_endpoint.verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
          end
        end
      end
    end
  end
end
