require 'more_core_extensions/core_ext/hash'
require "topological_inventory/openshift/logging"
require "topological_inventory/openshift/connection"
require "topological_inventory/openshift/operations/core/authentication_retriever"
require "topological_inventory/providers/common/mixins/sources_api"
require "topological_inventory/providers/common/mixins/topology_api"

module TopologicalInventory
  module Openshift
    module Operations
        class ServiceCatalogClient
          include Logging
          include TopologicalInventory::Providers::Common::Mixins::SourcesApi
          include TopologicalInventory::Providers::Common::Mixins::TopologyApi

          attr_accessor :connection_manager, :source_id, :task_id, :identity

          def initialize(source_id, task_id, identity = nil)
            self.identity   = identity
            self.source_id  = source_id
            self.task_id    = task_id

            self.connection_manager = TopologicalInventory::Openshift::Connection.new
          end

          def order_service(plan_name, service_offering_name, additional_parameters)
            payload = build_payload(plan_name, service_offering_name, additional_parameters)
            servicecatalog_connection.create_service_instance(payload)
          end

          def wait_for_provision_complete(name, namespace)
            field_selector = "involvedObject.kind=ServiceInstance,involvedObject.name=#{name}"

            watch = kubernetes_connection.watch_events(:namespace => namespace, :field_selector => field_selector)
            watch.each do |notice|
              event = notice.object

              logger.info("#{event.involvedObject.name}: message [#{event.message}] reason [#{event.reason}]")
              context = {:reason => event.reason, :message => event.message}
              update_task(task_id, :state => "running", :status => "ok", :context => context)

              next unless %w[ProvisionedSuccessfully ProvisionCallFailed].include?(event.reason)

              service_instance = servicecatalog_connection.get_service_instance(name, namespace)
              return service_instance, event.reason, event.message
            end
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

          def kubernetes_connection
            raw_connect("kubernetes")
          end

          def servicecatalog_connection
            raw_connect("servicecatalog")
          end

          def raw_connect(service)
            raise "Unable to find a default endpoint for source [#{source_id}]" if endpoint.nil?
            raise "Unable to find an authentication for source [#{source_id}]"  if authentication.nil?

            Thread.current["#{service}_connection"] ||= begin
              connection_manager.connect(
                service, :host => endpoint.host, :token => authentication.password, :verify_ssl => verify_ssl_mode
              )
            end
          end
        end
      end
  end
end
