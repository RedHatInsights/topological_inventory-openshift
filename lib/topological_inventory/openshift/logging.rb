require "topological_inventory/providers/common/logging"

module TopologicalInventory
  module Openshift
    class << self
      attr_writer :logger
    end

    def self.logger
      @logger ||= TopologicalInventory::Providers::Common::Logger.new
    end

    module Logging
      def logger
        TopologicalInventory::Openshift.logger
      end
    end
  end
end
