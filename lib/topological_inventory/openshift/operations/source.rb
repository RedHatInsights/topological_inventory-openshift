module TopologicalInventory
  module Openshift
    module Operations
      module Source
        def self.availability_check(params)
          puts "Running: availability_check for Source id: #{params["source_id"]}"
        end
      end
    end
  end
end
