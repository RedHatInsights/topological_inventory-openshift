module TopologicalInventory
  module Openshift
    module Operations
      module Core
        module TaskUpdate
          def update_task(task_id, state:, status:, context:)
            task = TopologicalInventoryApiClient::Task.new("state" => state, "status" => status, "context" => context.to_json)
            api_client.update_task(task_id, task)
          end
        end
      end
    end
  end
end
