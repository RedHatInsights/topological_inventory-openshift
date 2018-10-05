require "kubeclient"
require "openssl"

module Openshift
  module Connection
    class << self
      def kubernetes(host:, port: 8443, path: "/api", api_version: "v1", token:, verify_ssl: OpenSSL::SSL::VERIFY_NONE)

        open(host, port, path, api_version, token, verify_ssl)
      end

      def openshift(host:, port: 8443, path: "/oapi", api_version: "v1", token:, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
        open(host, port, path, api_version, token, verify_ssl)
      end

      def servicecatalog(host:, port: 8443, path: "/apis/servicecatalog.k8s.io", api_version: "v1beta1", token:, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
        open(host, port, path, api_version, token, verify_ssl)
      end

      def open(host, port, path, api_version, token, verify_ssl)
        endpoint_uri = URI::HTTPS.build(:host => host, :port => port, :path => path)

        options = {
          :ssl_options  => {:verify_ssl => verify_ssl},
          :auth_options => {:bearer_token => token}
        }

        Kubeclient::Client.new(endpoint_uri, api_version, options).tap { |c| c.discover }
      end
    end
  end
end
