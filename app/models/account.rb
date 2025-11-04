class Account < ApplicationRecord
  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users
  has_many :insales, dependent: :destroy
  has_many :swatch_groups, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :lists, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_many :discounts, dependent: :destroy
  has_many :webforms, dependent: :destroy
  has_many :incases, dependent: :destroy
  validates :name, presence: true

  # Set current account context
  def self.current
    Thread.current[:current_account_id] ? Account.find(Thread.current[:current_account_id]) : nil
  end

  def self.current=(account)
    Thread.current[:current_account_id] = account&.id
  end

  # Switch to this account context
  def switch_to
    Account.current = self
    self
  end

  # Switch to account by ID
  def self.switch_to(account_id)
    Account.find(account_id).switch_to
  end
end


# # Switch to account 5
# Account.switch_to(5)

# # Now all queries are automatically scoped to account 5
# Product.all          # Same as Product.where(account_id: 5)
# Client.all          # Same as Client.where(account_id: 5)
# Product.first       # First product for account 5
# Product.count       # Count of products for account 5
