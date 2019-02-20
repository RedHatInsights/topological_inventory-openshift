module TopologicalInventory
  module Openshift
    class << self
      attr_writer :logger
    end

    def self.logger
      @logger ||= Logger.new(STDOUT, :level => Logger::INFO)
    end

    module Logging
      def logger
        TopologicalInventory::Openshift.logger
      end
    end
  end
end
