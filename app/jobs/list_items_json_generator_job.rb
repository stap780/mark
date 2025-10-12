class ListItemsJsonGeneratorJob < ApplicationJob
  queue_as :list_items_json_generator

  def perform(account_id, external_client_id, client_id)
    ListItemsJsonGeneratorService.new(account_id, external_client_id, client_id).call
  end
end


