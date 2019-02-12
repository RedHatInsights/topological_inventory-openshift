require "kubeclient"
require "openssl"
require "active_support/core_ext/numeric/time"

module TopologicalInventory::Openshift
  class Connection
    def initialize
      @connection_failure_time = {}
    end

    def connect(endpoint_type, host:, port: 8443, token:, verify_ssl: OpenSSL::SSL::VERIFY_NONE, endpoint_retry_minutes: 60)
      raise "Invalid endpoint type: #{endpoint_type}" unless valid_endpoint_types.include?(endpoint_type)

      last_failure_time = connection_failure_time[endpoint_type]
      return if last_failure_time && last_failure_time > endpoint_retry_minutes.minutes.ago.utc

      params = connect_params(endpoint_type)
      params.merge!(:host => host, :port => port, :token => token, :verify_ssl => verify_ssl)

      open(*params.values_at(:host, :port, :path, :api_version, :token, :verify_ssl))
    rescue => err
      connection_failure_time[endpoint_type] = Time.now.utc
      raise
    end

    private

    attr_accessor :connection_failure_time

    def valid_endpoint_types
      %w(kubernetes openshift servicecatalog)
    end

    def connect_params(endpoint_type)
      case endpoint_type
      when "kubernetes"
        {:port => 8443, :path => "/api", :api_version => "v1"}
      when "openshift"
        {:port => 8443, :path => "/oapi", :api_version => "v1"}
      when "servicecatalog"
        {:port => 8443, :path => "/apis/servicecatalog.k8s.io", :api_version => "v1beta1"}
      end
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
