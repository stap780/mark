class IncaseItem < ApplicationRecord
  belongs_to :incase
  belongs_to :item, polymorphic: true

  validates :item_type, :item_id, presence: true
end


