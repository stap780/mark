class User < ApplicationRecord
  include ActionView::RecordIdentifier
  include AccountScoped

  belongs_to :account
  has_secure_password
  has_many :sessions, dependent: :destroy

  enum :role, { admin: "admin", member: "member" }, default: "member"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: { scope: :account_id }
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  validates :password_confirmation, presence: true, if: :password_required?
  validate :only_one_admin_per_account, if: :admin?

  # Hotwire broadcasts
  after_create_commit do
    broadcast_append_to dom_id(account, :users),
                        target: dom_id(account, :users),
                        partial: "users/user",
                        locals: { user: self, current_account: account }
  end

  after_update_commit do
    broadcast_replace_to dom_id(account, :users),
                        target: dom_id(account, dom_id(self)),
                        partial: "users/user",
                        locals: { user: self, current_account: account }
  end

  after_destroy_commit do
    broadcast_remove_to dom_id(account, :users), target: dom_id(account, dom_id(self))
  end

  private

  def password_required?
    new_record? || password.present?
  end

  def only_one_admin_per_account
    existing_admin = account.users.where(role: 'admin').where.not(id: id)
    if existing_admin.exists?
      errors.add(:role, 'can only have one admin per account')
    end
  end
end
