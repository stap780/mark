class Account < ApplicationRecord
  has_many :users
  has_many :insales, dependent: :destroy
  has_many :swatch_groups, dependent: :destroy
  has_many :products, dependent: :destroy
  validates :name, presence: true
end
