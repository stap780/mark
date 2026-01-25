module ConversationServices
  class MessageSender
    def initialize(conversation:, channel:, content:, subject: nil, sms_provider: nil, user: nil)
      @conversation = conversation
      @account = conversation.account
      @client = conversation.client
      @channel = channel.to_s
      @content = content
      @subject = subject
      @sms_provider = sms_provider
      @user = user
    end

    def call
      # Создаем запись Message с direction: 'outgoing'
      message = @conversation.messages.build(
        account: @account,
        client: @client,
        direction: 'outgoing',
        channel: @channel,
        content: @content,
        subject: @subject,
        user: @user,
        status: 'sent',
        sent_at: Time.current
      )

      # Отправляем сообщение через соответствующий канал
      result = case @channel
               when 'telegram'
                 send_telegram
               when 'email'
                 send_email
               when 'sms'
                 send_sms
               else
                 { ok: false, error: "Unknown channel: #{@channel}" }
               end

      # Обновляем message на основе результата
      if result[:ok]
        message.message_id = result[:message_id].to_s if result[:message_id]
        message.save!
      else
        message.status = 'failed'
        message.error_message = result[:error] || "Unknown error"
        message.save!
      end

      # Обновляем timestamps conversation
      @conversation.update_timestamps

      { ok: result[:ok], message: message, error: result[:error] }
    rescue => e
      Rails.logger.error "ConversationServices::MessageSender error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { ok: false, error: e.message }
    end

    private

    def send_telegram
      return { ok: false, error: "У клиента нет контакта в Telegram" } unless @client.telegram_chat_id.present? || @client.telegram_username.present? || @client.phone.present?

      sender = TelegramProviders::MessageSender.new(account: @account)
      result = sender.send(client: @client, text: @content)

      if result[:ok]
        {
          ok: true,
          message_id: result[:message_id],
          provider: result[:channel]
        }
      else
        { ok: false, error: result[:error] || "Unknown error" }
      end
    end

    def send_email
      return { ok: false, error: "У клиента нет email адреса" } unless @client.email.present?

      # Проверяем настройки Mailganer
      mailganer_settings = @account.mailganer || MailganerClient.configuration
      return { ok: false, error: "Mailganer не настроен" } unless mailganer_settings

      # Проверяем лимит для глобальной конфигурации
      if @account.mailganer.blank?
        can_send, error_message = Mailganer.can_send_email_via_global_mailganer?(account: @account)
        return { ok: false, error: error_message } unless can_send
      end

      mailganer_client = MailganerClient::Client.new(
        api_key: mailganer_settings.api_key,
        smtp_login: mailganer_settings.smtp_login,
        api_key_web_portal: mailganer_settings.api_key_web_portal
      )

      from_email = if mailganer_settings.respond_to?(:from_email)
        mailganer_settings.from_email.presence || "info@teletri.ru"
      else
        "info@teletri.ru"
      end

      x_track_id = [
        mailganer_settings.smtp_login.presence || "mailganer",
        Time.now.to_i,
        "conv-#{@conversation.id}"
      ].join("-")

      response = mailganer_client.send_email_smtp_v1(
        type: "body",
        to: @client.email,
        from: from_email,
        subject: @subject || "Сообщение",
        body: @content,
        x_track_id: x_track_id
      )

      message_id = response[:message_id] || response["message_id"]

      {
        ok: true,
        message_id: message_id,
        provider: 'mailganer'
      }
    rescue => e
      Rails.logger.error "Failed to send conversation email: #{e.message}"
      { ok: false, error: e.message.to_s }
    end

    def send_sms
      return { ok: false, error: "У клиента нет номера телефона" } unless @client.phone.present?

      # Если указан провайдер, используем его
      if @sms_provider.present?
        case @sms_provider
        when 'idgtl'
          return send_sms_via_idgtl if @account.idgtl.present?
          return { ok: false, error: "i-dgtl не настроен" }
        when 'moizvonki'
          return send_sms_via_moizvonki if @account.moizvonki.present?
          return { ok: false, error: "Moizvonki не настроен" }
        else
          return { ok: false, error: "Неизвестный SMS провайдер: #{@sms_provider}" }
        end
      end

      # Если провайдер не указан, используем автоматический выбор (приоритет: i-dgtl, потом Moizvonki)
      if @account.idgtl.present?
        return send_sms_via_idgtl
      elsif @account.moizvonki.present?
        return send_sms_via_moizvonki
      else
        return { ok: false, error: "SMS провайдер не настроен" }
      end
    end

    def send_sms_via_idgtl
      idgtl_settings = @account.idgtl
      client = SmsProviders::IdgtlClient.new(token_1: idgtl_settings.token_1)
      result = client.send_sms!(
        sender_name: idgtl_settings.sender_name,
        destination: @client.phone,
        content: @content,
        external_message_id: "conv-#{@conversation.id}"
      )

      {
        ok: true,
        message_id: result[:message_uuid],
        provider: 'idgtl'
      }
    rescue SmsProviders::IdgtlClient::ApiError => e
      { ok: false, error: "i-dgtl error (#{e.http_status}): #{e.raw}" }
    rescue => e
      { ok: false, error: e.message.to_s }
    end

    def send_sms_via_moizvonki
      moizvonki_settings = @account.moizvonki
      client = SmsProviders::MoizvonkiClient.new(
        domain: moizvonki_settings.domain,
        user_name: moizvonki_settings.user_name,
        api_key: moizvonki_settings.api_key
      )
      client.send_sms!(to: @client.phone, text: @content)

      {
        ok: true,
        message_id: "conv-#{@conversation.id}",
        provider: 'moizvonki'
      }
    rescue SmsProviders::MoizvonkiClient::ApiError => e
      { ok: false, error: "Moizvonki error (#{e.http_status}): #{e.raw}" }
    rescue => e
      { ok: false, error: e.message.to_s }
    end
  end
end
