require "topological_inventory/providers/common/logging"

module TopologicalInventory
  module Openshift
    APP_NAME = "topological-inventory-openshift-operations".freeze

    class << self
      attr_writer :logger
    end

    class Formatter < ManageIQ::Loggers::Container::Formatter
      def call(severity, time, progname, msg)
        payload = {
          :"ecs.version" => "1.5.0",
          :@timestamp    => format_datetime(time),
          :hostname      => hostname,
          :pid           => $PROCESS_ID,
          :tid           => thread_id,
          :service       => progname,
          :level         => translate_error(severity),
          :message       => prefix_task_id(msg2str(msg)),
          :request_id    => request_id,
          :tags          => [APP_NAME],
          :labels        => {"app" => APP_NAME}
        }.compact
        JSON.generate(payload) << "\n"
      end
    end

    def self.log_to_stderr?
      ENV['LOG_HANDLER'] == "haberdasher"
    end

    def self.logger
      @logger ||= begin
                    provider_logger = TopologicalInventory::Providers::Common::Logger.new
                    provider_logger.reopen(STDERR) if log_to_stderr?
                    provider_logger.formatter = Formatter.new
                    provider_logger
                  end
    end

    module Logging
      def logger
        TopologicalInventory::Openshift.logger
      end
    end
  end
end
