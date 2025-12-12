class AutomationMessage < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :automation_rule
  belongs_to :automation_action
  belongs_to :client
  belongs_to :incase, optional: true

  enum :channel, { email: 'email', whatsapp: 'whatsapp', telegram: 'telegram', sms: 'sms' }
  enum :status, { pending: 'pending', sent: 'sent', failed: 'failed', delivered: 'delivered' }

  scope :sent, -> { where(status: 'sent') }
  scope :failed, -> { where(status: 'failed') }
  scope :by_channel, ->(channel) { where(channel: channel) }
  scope :recent, -> { order(created_at: :desc) }

  def self.ransackable_attributes(auth_object = nil)
    AutomationMessage.attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[automation_rule automation_action client incase]
  end
end

