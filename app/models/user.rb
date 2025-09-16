class User < ApplicationRecord
  belongs_to :account
  has_secure_password
  has_many :sessions, dependent: :destroy

  enum :role, { admin: "admin", member: "member" }, default: "member"

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
