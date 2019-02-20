require "rest_client"
require "topological_inventory/openshift/operations/core/authentication_retriever"
require "topological_inventory/openshift/operations/core/service_plan_client"
require "topological_inventory/openshift/operations/core/source_endpoints_retriever"

module TopologicalInventory
  module Openshift
    module Operations
      module Core
        class ServiceCatalogClient
          def initialize(source_id)
            all_source_endpoints = SourceEndpointsRetriever.new(source_id).process
            @default_endpoint = all_source_endpoints.data.find { |endpoint| endpoint.default }

            @authentication = AuthenticationRetriever.new(@default_endpoint.id).process
          end

          def order_service_plan(plan_name, service_offering_name, additional_parameters)
            payload = ServicePlanClient.new.build_payload(plan_name, service_offering_name, additional_parameters)
            response = external_request(:post, order_service_plan_url, payload)
            JSON.parse(response.body)
          end

          private

          def order_service_plan_url
            base_url_path = URI::Generic.build(
              :scheme => @default_endpoint.scheme,
              :host   => @default_endpoint.host,
              :port   => @default_endpoint.port,
              :path   => @default_endpoint.path
            ).to_s
            URI.join(base_url_path, "apis/servicecatalog.k8s.io/v1beta1/namespaces/default/serviceinstances").to_s
          end

          def external_request(method, url, payload, headers = generic_headers)
            request_options = {
              :method     => method,
              :url        => url,
              :headers    => headers,
              :verify_ssl => verify_ssl_mode,
              :payload    => payload
            }

            RestClient::Request.new(request_options).execute
          end

          def generic_headers
            {
              "Authorization" => "Bearer #{@authentication.password}",
              "Content-Type"  => "application/json",
              "Accept"        => "application/json"
            }
          end

          def verify_ssl_mode
            @default_endpoint.verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
          end
        end
      end
    end
  end
end
