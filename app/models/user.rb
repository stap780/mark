class User < ApplicationRecord
  include ActionView::RecordIdentifier

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :account_users, dependent: :destroy
  has_many :accounts, through: :account_users
  has_one :inswatch, dependent: :destroy
  has_one :insnotify, dependent: :destroy
  
  accepts_nested_attributes_for :account_users, allow_destroy: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  validates :password_confirmation, presence: true, if: :password_required?

  # Вспомогательные методы для работы с ролями в аккаунтах
  def role_in_account(account)
    account_users.find_by(account: account)&.role
  end

  def admin_in_account?(account)
    role_in_account(account) == 'admin'
  end

  def admin_in_any_account?
    account_users.where(role: 'admin').exists?
  end

  private

  def password_required?
    new_record? || password.present?
  end
  
end
