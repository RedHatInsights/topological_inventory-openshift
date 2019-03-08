require 'more_core_extensions/core_ext/hash'
require "topological_inventory/openshift/connection"
require "topological_inventory/openshift/operations/core/authentication_retriever"
require "topological_inventory-api-client"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        class ServiceCatalogClient
          attr_accessor :default_endpoint, :authentication, :connection_manager

          def initialize(source_id)
            api_client = TopologicalInventoryApiClient::DefaultApi.new

            all_source_endpoints = api_client.list_source_endpoints(source_id)
            self.default_endpoint = all_source_endpoints.data.find { |endpoint| endpoint.default }

            authentication_id = api_client.list_endpoint_authentications(default_endpoint.id.to_s).data.first&.id
            self.authentication = AuthenticationRetriever.new(authentication_id).process

            self.connection_manager = TopologicalInventory::Openshift::Connection.new
          end

          def order_service_plan(plan_name, service_offering_name, additional_parameters)
            connection = connection_manager.connect(
              "servicecatalog", host: default_endpoint.host, token: authentication.password, verify_ssl: verify_ssl_mode)

            payload = build_payload(plan_name, service_offering_name, additional_parameters)
            connection.create_service_instance(payload)
          end

          private

          def build_payload(service_plan_name, service_offering_name, order_parameters)
            # We need to not send empty strings in case the parameter is generated
            # More details are explained in the comment in the OpenShift web catalog
            # https://github.com/openshift/origin-web-catalog/blob/4c5cb3ee1ae0061ed28fc6190a0f8fff71771122/src/components/order-service/order-service.controller.ts#L442
            safe_params = order_parameters["service_parameters"].delete_blanks

            {
              :metadata   => {
                :name      => "#{service_offering_name}-#{SecureRandom.uuid}",
                :namespace => order_parameters["provider_control_parameters"]["namespace"]
              },
              :spec       => {
                :clusterServiceClassExternalName => service_offering_name,
                :clusterServicePlanExternalName  => service_plan_name,
                :parameters                      => safe_params
              }
            }
          end

          def verify_ssl_mode
            default_endpoint.verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
          end
        end
      end
    end
  end
end
