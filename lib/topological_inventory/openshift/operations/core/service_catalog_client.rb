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

          attr_accessor :default_endpoint, :authentication, :connection_manager, :sleep_poll

          def initialize(source_id)
            self.sleep_poll = 10

            api_client = TopologicalInventoryApiClient::DefaultApi.new

            all_source_endpoints = api_client.list_source_endpoints(source_id)
            self.default_endpoint = all_source_endpoints.data.find(&:default)

            authentication_id = api_client.list_endpoint_authentications(default_endpoint.id.to_s).data.first&.id
            self.authentication = AuthenticationRetriever.new(authentication_id).process

            self.connection_manager = TopologicalInventory::Openshift::Connection.new
          end

          def order_service_plan(plan_name, service_offering_name, additional_parameters)
            connection = connection_manager.connect(
              "servicecatalog", :host => default_endpoint.host, :token => authentication.password, :verify_ssl => verify_ssl_mode
            )

            payload = build_payload(plan_name, service_offering_name, additional_parameters)

            service_instance = connection.create_service_instance(payload)

            logger.info("Waiting for #{service_instance.metadata.name} to provision...")
            service_instance = wait_for_provision_complete(connection, service_instance)
            logger.info("Waiting for #{service_instance.metadata.name} to provision...Complete")

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

          def wait_for_provision_complete(connection, service_instance)
            loop do
              sleep(sleep_poll)

              service_instance = connection.get_service_instance(
                service_instance.metadata.name,
                service_instance.metadata.namespace
              )

              condition = service_instance.status.conditions.first
              logger.info("#{service_instance.metadata.name}: message [#{condition.message}] status [#{condition.status}] reason [#{condition.reason}]")

              break unless service_instance_provisioning?(service_instance)
            end

            service_instance
          end

          def service_instance_provisioning?(service_instance)
            reason = service_instance.status.conditions.first&.reason
            %w[Provisioning ProvisionRequestInFlight].include?(reason)
          end

          def verify_ssl_mode
            default_endpoint.verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
          end
        end
      end
    end
  end
end
