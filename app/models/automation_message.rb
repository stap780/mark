class AutomationMessage < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :automation_rule
  belongs_to :automation_action
  belongs_to :client
  belongs_to :incase, optional: true

  enum :channel, { email: 'email', whatsapp: 'whatsapp', telegram: 'telegram', sms: 'sms' }
  enum :status, { pending: 'pending', sent: 'sent', failed: 'failed', delivered: 'delivered', email_fbl: 'email_fbl', email_unsubscribe: 'email_unsubscribe', email_open: 'email_open', email_click: 'email_click' }

  scope :sent, -> { where(status: 'sent') }
  scope :failed, -> { where(status: 'failed') }
  scope :delivered, -> { where(status: 'delivered') }
  scope :email_fbl, -> { where(status: 'email_fbl') }
  scope :email_unsubscribe, -> { where(status: 'email_unsubscribe') }
  scope :email_open, -> { where(status: 'email_open') }
  scope :email_click, -> { where(status: 'email_click') }
  scope :by_channel, ->(channel) { where(channel: channel) }
  scope :recent, -> { order(created_at: :desc) }
  
  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[automation_rule automation_action client incase]
  end

  # Маппинг статусов Mailganer → статусы AutomationMessage
  MAILGANER_STATUS_MAPPING = {
    'accepted' => 'sent',
    'delivered' => 'delivered',
    'failed' => 'failed',
    'fbl' => 'email_fbl',
    'unsubscribe' => 'email_unsubscribe',
    'open' => 'email_open',
    'click' => 'email_click'
  }.freeze

  # Проверяет статус доставки этого сообщения.
  # Обновляет статус AutomationMessage на основе ответа Mailganer.
  def check_delivery_status
    unless email?
      return [false, "Проверка статуса доступна только для email-сообщений"]
    end

    if message_id.blank? && x_track_id.blank?
      return [false, "Для этого сообщения нет данных message_id / x_track_id"]
    end

    success, result = Mailganer.check_delivery_status_for(
      account: account,
      message_id: message_id,
      x_track_id: x_track_id
    )

    return [success, result] unless success

    # Обновляем статус AutomationMessage на основе статуса из Mailganer
    if result.is_a?(Hash) && result[:status].present?
      mailganer_status = result[:status].to_s.downcase
      new_status = MAILGANER_STATUS_MAPPING[mailganer_status]
      
      if new_status && status != new_status
        update_column(:status, new_status)
      end
    end

    [success, result]
  end
  
end

