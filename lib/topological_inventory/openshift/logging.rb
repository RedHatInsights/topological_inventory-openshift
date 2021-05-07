require "insights/loggers"

module TopologicalInventory
  module Openshift
    APP_NAME = "topological-inventory-openshift-operations".freeze

    class << self
      attr_writer :logger
    end

    def self.logger_class
      if ENV['LOG_HANDLER'] == "haberdasher"
        "Insights::Loggers::StdErrorLogger"
      else
        "TopologicalInventory::Providers::Common::Logger"
      end
    end

    def self.logger
      log_params = {:app_name => APP_NAME}

      if logger_class == "Insights::Loggers::StdErrorLogger"
        log_params[:extend_module] = "TopologicalInventory::Providers::Common::LoggingFunctions"
      end

      @logger ||= Insights::Loggers::Factory.create_logger(logger_class, log_params)
    end

    module Logging
      def logger
        TopologicalInventory::Openshift.logger
      end
    end
  end
end
