class ListItem < ApplicationRecord
  belongs_to :list
  belongs_to :item, polymorphic: true
  belongs_to :client

  def self.ransackable_attributes(auth_object = nil)
    ["client_id", "created_at", "id", "item_id", "item_type", "list_id", "updated_at"]
  end

end
