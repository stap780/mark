class Account < ApplicationRecord
  has_many :users
  has_many :insales, dependent: :destroy
  validates :name, presence: true
end
