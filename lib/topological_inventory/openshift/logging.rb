require "manageiq/loggers"

module TopologicalInventory
  module Openshift
    class << self
      attr_writer :logger
    end

    def self.logger
      @logger ||= ManageIQ::Loggers::Container.new
    end

    module Logging
      def logger
        TopologicalInventory::Openshift.logger
      end
    end
  end
end
