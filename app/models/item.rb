class Item < ApplicationRecord
  belongs_to :incase
  belongs_to :product
  belongs_to :variant

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def sum
    (quantity || 0) * (price || 0)
  end
end

