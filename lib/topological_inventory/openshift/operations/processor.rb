require "topological_inventory/openshift/logging"
require "topological_inventory/openshift/operations/service_plan"
require "topological_inventory/openshift/operations/source"
require "topological_inventory/providers/common/operations/processor"

module TopologicalInventory
  module Openshift
    module Operations
      class Processor < TopologicalInventory::Providers::Common::Operations::Processor
        include Logging

        def operation_class
          "#{Operations}::#{model}".safe_constantize
        end
      end
    end
  end
end
