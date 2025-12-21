class Mailganer < ApplicationRecord
  include AccountScoped

  belongs_to :account

  validates :account_id, uniqueness: true
  validates :api_key, :smtp_login, :api_key_web_portal, presence: true

  # Отправка тестового письма. Вся логика и обработка ошибок находятся в модели.
  #
  # @param to_email [String] email получателя
  # @return [Array(Boolean, String)] успех/ошибка и человекочитаемое сообщение
  def send_test_email(to_email)
    if to_email.blank?
      return [false, I18n.t('mailganers.test_email.email_blank')]
    end

    client = MailganerClient::Client.new(
      api_key: api_key,
      smtp_login: smtp_login,
      api_key_web_portal: api_key_web_portal
    )

    x_track_id = "#{smtp_login}-#{Time.now.to_i}-test"

    response = client.send_email_smtp_v1(
      type: "body",
      to: to_email,
      from: "info@teletri.ru",
      subject: "Test email from Mailganer",
      body: "This is a test email from Mailganer settings for account ##{account_id}",
      x_track_id: x_track_id
    )

    if response[:status].to_s.upcase == "OK"
      [true, I18n.t('mailganers.test_email.success')]
    else
      [false, I18n.t('mailganers.test_email.failed')]
    end
  rescue => e
    [false, I18n.t('mailganers.test_email.error', msg: e.message)]
  end

  # Класс-метод: проверяет, можно ли отправить письмо через глобальную конфигурацию Mailganer.
  # Если у аккаунта есть свой Mailganer, ограничение не применяется.
  #
  # @param account [Account]
  # @return [Array(Boolean, String)] [можно_отправить, сообщение_об_ошибке]
  def self.can_send_email_via_global_mailganer?(account:)
    # Если у аккаунта есть свой Mailganer, ограничение не применяется
    return [true, nil] if account.mailganer.present?

    # Лимит для глобальной конфигурации
    limit = 50

    # Подсчитываем отправленные письма за текущий месяц
    current_month_start = Time.current.beginning_of_month
    current_month_end = Time.current.end_of_month

    sent_count = account.automation_messages
      .where(channel: 'email', status: 'sent')
      .where(sent_at: current_month_start..current_month_end)
      .count

    if sent_count >= limit
      message = I18n.t('automation_messages.global_mailganer_limit_exceeded',
                       limit: limit,
                       count: sent_count,
                       reset_date: current_month_end.strftime('%d.%m.%Y'))
      [false, message]
    else
      [true, nil]
    end
  end

  # Класс-метод: проверяет статус доставки сообщения.
  # Если у аккаунта есть Mailganer — используется его конфигурация,
  # иначе используется глобальная конфигурация MailganerClient.
  #
  # @param account [Account,nil]
  # @param message_id [String,nil]
  # @param x_track_id [String,nil]
  # @return [Array(Boolean, String)]
  def self.check_delivery_status_for(account:, message_id:, x_track_id: nil)
    if account&.mailganer
      client = MailganerClient::Client.new(
        api_key: account.mailganer.api_key,
        smtp_login: account.mailganer.smtp_login,
        api_key_web_portal: account.mailganer.api_key_web_portal
      )
    else
      client = MailganerClient::Client.new
    end

    response = client.status_email_delivery(
      message_id: message_id.presence,
      x_track_id: x_track_id.presence
    )

    # Формат ответа Mailganer:
    # {
    #   status: "ok",
    #   messages: [
    #     {
    #       message_id: "...",
    #       x_track_id: "...",
    #       status: "failed", # accepted, delivered, failed, fbl, unsubscribe, open, click
    #       reason: "....",   # опционально
    #       created_at: 1697746906 # timestamp (UTC+3)
    #     },
    #     ...
    #   ]
    # }
    messages = Array(response[:messages])

    message_entry =
      messages.find { |m| m[:message_id].to_s == message_id.to_s } ||
      messages.find { |m| x_track_id.present? && m[:x_track_id].to_s == x_track_id.to_s } ||
      messages.first

    unless message_entry
      return [true, { text: "Статус доставки: данных по сообщению не найдено", raw: response }]
    end

    status = message_entry[:status].to_s # accepted, delivered, failed, fbl, unsubscribe, open, click
    reason = message_entry[:reason].to_s.presence

    created_at =
      if message_entry[:created_at]
        # timestamp в UTC+3 — приводим к текущей таймзоне приложения
        ts = message_entry[:created_at].to_i
        Time.zone ? Time.zone.at(ts) : Time.at(ts)
      end

    result = {
      status: status,
      reason: reason,
      created_at: created_at,
      raw: response
    }

    [true, result]
  rescue => e
    [false, { text: "Ошибка проверки статуса доставки: #{e.message}" }]
  end

end


