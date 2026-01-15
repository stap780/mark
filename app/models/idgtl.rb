class Idgtl < ApplicationRecord
  include AccountScoped

  belongs_to :account

  validates :account_id, uniqueness: true
  validates :token_1, :sender_name, presence: true
end

