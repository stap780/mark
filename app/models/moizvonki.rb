class Moizvonki < ApplicationRecord
  include AccountScoped

  belongs_to :account

  before_validation :ensure_webhook_secret

  validates :account_id, uniqueness: true
  validates :domain, :user_name, :api_key, :webhook_secret, presence: true

  private

  def ensure_webhook_secret
    self.webhook_secret = SecureRandom.hex(16) if webhook_secret.blank?
  end
end

