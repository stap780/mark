class ListJsonGeneratorJob < ApplicationJob
  queue_as :list_json_generator

  def perform(account_id)
    ListJsonGeneratorService.new(account_id).call
  end
end