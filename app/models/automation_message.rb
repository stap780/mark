require "time"

class AutomationMessage < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :automation_rule
  belongs_to :automation_action
  belongs_to :client, optional: true
  belongs_to :user, optional: true
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
  
  # Генерируем события автоматизации при изменении статуса
  after_update_commit :trigger_automation_events, if: :saved_change_to_status?
  
  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[automation_rule automation_action client user incase]
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
    if email?
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
          update_attrs = { status: new_status }
          
          # Устанавливаем sent_at при изменении статуса на 'sent'
          if new_status == 'sent' && sent_at.nil?
            update_attrs[:sent_at] = result[:created_at] || Time.current
          end
          
          # Устанавливаем delivered_at при изменении статуса на 'delivered'
          if new_status == 'delivered' && delivered_at.nil?
            update_attrs[:delivered_at] = result[:created_at] || Time.current
          end
          
          update_columns(update_attrs)
        end
      end

      return [success, result]
    end

    if sms?
      if automation_action&.kind != "send_sms_idgtl"
        return [false, "Проверка статуса доступна только для SMS i-dgtl"]
      end

      idgtl_settings = account&.idgtl
      return [false, "i-dgtl не настроен для аккаунта"] unless idgtl_settings

      lookup_id = message_id.presence || x_track_id.presence
      return [false, "Для этого сообщения нет данных message_id / x_track_id"] unless lookup_id

      client = SmsProviders::IdgtlClient.new(token_1: idgtl_settings.token_1)
      res = client.get_message!(id: lookup_id)

      if res[:http_status].to_i == 404
        return [true, { text: "Статус ещё не доступен (404). Попробуйте позже.", raw: res[:raw] }]
      end

      unless res[:ok] && res[:raw].is_a?(Hash)
        return [false, { text: "Ошибка проверки статуса i-dgtl (HTTP #{res[:http_status]})", raw: res[:raw] }]
      end

      remote_status = res[:raw]["status"].to_s.downcase
      status_time_raw = res[:raw]["statusTime"].presence || res[:raw]["sentTime"].presence
      status_time =
        if status_time_raw.present?
          begin
            Time.zone ? Time.zone.parse(status_time_raw.to_s) : Time.parse(status_time_raw.to_s)
          rescue ArgumentError
            nil
          end
        end

      # i-dgtl statuses (examples): sent, delivered, undelivered
      new_status =
        case remote_status
        when "delivered" then "delivered"
        when "undelivered", "failed" then "failed"
        when "sent", "accepted" then "sent"
        else
          nil
        end

      if new_status && status != new_status
        update_attrs = { status: new_status }
        update_attrs[:sent_at] ||= Time.current if new_status == "sent" && sent_at.nil?
        update_attrs[:delivered_at] ||= Time.current if new_status == "delivered" && delivered_at.nil?

        if new_status == "failed"
          error_code = res[:raw]["errorCode"]
          update_attrs[:error_message] = ["i-dgtl status=#{remote_status}", ("errorCode=#{error_code}" if error_code)].compact.join(" ")
        end

        update_columns(update_attrs)
      end

      return [true, { status: remote_status, created_at: status_time, raw: res[:raw] }]
    end

    [false, "Проверка статуса доступна только для email и SMS"]
  end

  private

  def trigger_automation_events
    # Генерируем событие только при переходе в финальные статусы
    return unless status.in?(['sent', 'failed'])

    event_name = case status
                 when 'sent'
                   'automation_message.sent'
                 when 'failed'
                   'automation_message.failed'
                 end

    return unless event_name

    # Вызываем Automation::Engine с контекстом сообщения
    Automation::Engine.call(
      account: account,
      event: event_name,
      object: self,
      context: {
        automation_message: self,
        incase: incase,
        client: client
      }
    )
  end
  
end

