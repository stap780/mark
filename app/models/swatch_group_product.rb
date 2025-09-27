class SwatchGroupProduct < ApplicationRecord
  belongs_to :swatch_group
  belongs_to :product

  validates :swatch_value, presence: true
  validates :product_id, uniqueness: { scope: :swatch_group_id }

  scope :ordered, -> { order(:id) }
end
