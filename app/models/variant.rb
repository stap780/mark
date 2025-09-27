class Variant < ApplicationRecord
  belongs_to :product
  has_many :varbinds, dependent: :destroy
end


