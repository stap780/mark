class ListItem < ApplicationRecord
  belongs_to :list
  belongs_to :item, polymorphic: true
  belongs_to :client

  after_commit :regenerate_owner_cache

  private

  def regenerate_owner_cache
    ListJsonCacheJob.perform_later(account_id: list.account_id, owner_type: 'Client', owner_id: client_id)
  end
end
