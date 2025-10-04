class ListJsonCacheJob < ApplicationJob
  queue_as :default

  def perform(account_id:, owner_type:, owner_id:)
    ListJsonCacheService.new(account_id: account_id, owner_type: owner_type, owner_id: owner_id).call
  end
end


