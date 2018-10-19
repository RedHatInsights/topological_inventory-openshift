require "openshift/collector"
require "openshift/mock/connection"

module Openshift
  module Mock
    class Collector < ::Openshift::Collector
      def connection
        @connection ||= Openshift::Mock::Connection.new
      end

      def connection_for_entity_type(_entity_type = nil)
        connection
      end

      def watch(_connection, _entity_type, _resource_version)
        nil
      end
    end
  end
end
