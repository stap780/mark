class AccountUser < ApplicationRecord
  include ActionView::RecordIdentifier
  
  belongs_to :user
  belongs_to :account
  
  enum :role, { admin: "admin", member: "member" }, default: "member"
  
  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :account_id }
  
  validate :only_one_admin_per_account
  
  private
  
  def only_one_admin_per_account
    return unless admin?
    
    existing_admin = account.account_users.where(role: 'admin').where.not(id: id)
    if existing_admin.exists?
      errors.add(:role, :only_one_admin_per_account)
    end
  end
end
