module Automation
  class ActionExecutor
    def initialize(action, context, account)
      @action = action
      @context = context
      @account = account
    end

    def call
      case @action.kind
      when 'send_email'
        send_email
      when 'send_email_to_users'
        send_email_to_users
      when 'send_sms_idgtl'
        send_sms_idgtl
      when 'send_sms_moizvonki'
        send_sms_moizvonki
      when 'send_telegram'
        send_telegram
      when 'change_status'
        change_status
      else
        Rails.logger.warn "Unknown action kind: #{@action.kind}"
      end
    end

    private

    def send_email
      template_id = @action.template_id
      template = @account.message_templates.find_by(id: template_id)
      return unless template

      recipient = @context['client'] || @context[:client]
      return unless recipient&.email.present?

      # Для IncaseNotifyGroupByClient incases доступны через client.incases_for_notify
      # Для обычных автоматизаций передается одна заявка 'incase'
      incase = @context['incase'] || @context[:incase]
      
      # variants передаются из контекста (из IncaseNotifyGroupByClient)
      variants = @context['variants'] || []
      
      # variant и product передаются из контекста (для события variant.back_in_stock)
      variant = @context['variant'] || @context[:variant]
      product = @context['product'] || @context[:product]
      
      # Все заявки клиента (для IncaseNotifyGroupByClient)
      client_incases = @context['incases'] || @context[:incases]

      webform = @context['webform'] || incase&.webform

      # Строим контекст для Liquid через Drops
      # incases доступны через client.incases_for_notify в Liquid шаблоне
      # Передаем все заявки клиента в ClientDrop для доступа через client.incases_for_notify
      liquid_context = Automation::LiquidContextBuilder.build(
        incase: incase,
        client: recipient,
        client_incases: client_incases,
        webform: webform,
        variants: variants,
        variant: variant,
        product: product
      )

      rendered_subject = render_liquid(template.subject, liquid_context)
      rendered_content = render_liquid(template.content, liquid_context)

      # Создаем одну запись для одного письма
      message = @account.automation_messages.create!(
        automation_rule: @action.automation_rule,
        automation_action: @action,
        client: recipient,
        incase: incase, # Используем заявку для связи (если есть)
        channel: 'email',
        status: 'pending',
        subject: rendered_subject,
        content: rendered_content
      )

      # Отправляем email через Mailganer
      send_email_via_mailganer(message, recipient.email, rendered_subject, rendered_content)
    end

    def send_email_via_mailganer(message, to_email, rendered_subject, rendered_content)
      begin
        # Отправляем email через Mailganer
        # Используем настройки аккаунта, если есть, иначе глобальную конфигурацию
        # Проверяем лимит для глобальной конфигурации
        if @account.mailganer.blank?
          can_send, error_message = Mailganer.can_send_email_via_global_mailganer?(account: @account)
          unless can_send
            message.update!(
              status: 'failed',
              error_message: error_message
            )
            Rails.logger.warn "Email sending blocked for account ##{@account.id}: #{error_message}"
            return
          end
        end

        mailganer_settings = @account.mailganer || MailganerClient.configuration
        return unless mailganer_settings # Если Mailganer не настроен, не отправляем

        mailganer_client = MailganerClient::Client.new(
          api_key: mailganer_settings.api_key,
          smtp_login: mailganer_settings.smtp_login,
          api_key_web_portal: mailganer_settings.api_key_web_portal
        )

        # Определяем from_email: если это объект Mailganer, используем его from_email, иначе дефолт
        from_email = if mailganer_settings.respond_to?(:from_email)
          mailganer_settings.from_email.presence || "info@teletri.ru"
        else
          "info@teletri.ru"
        end

        # Формируем x_track_id в формате "#{smtp_login}-#{Time.now.to_i}-#{automation_message.id}"
        x_track_id = [
          mailganer_settings.smtp_login.presence || "mailganer",
          Time.now.to_i,
          message.id
        ].join("-")

        response = mailganer_client.send_email_smtp_v1(
          type: "body",
          to: to_email,
          from: from_email,
          subject: rendered_subject,
          body: rendered_content,
          x_track_id: x_track_id
        )

        # Ожидаемый ответ: { status: "OK", message_id: "..." }
        message_id = response[:message_id] || response["message_id"]

        message.update!(
          status: 'sent',
          sent_at: Time.current,
          message_id: message_id,
          x_track_id: x_track_id
        )
      rescue => e
        message.update!(status: 'failed',error_message: e.message)
        Rails.logger.error "Failed to send automation email: #{e.message.to_s}"
      end
    end

    def send_sms_idgtl
      template_id = @action.template_id
      template = @account.message_templates.find_by(id: template_id)
      return unless template

      recipient = @context['client'] || @context[:client]
      return unless recipient&.phone.present?

      incase = @context['incase'] || @context[:incase]
      variants = @context['variants'] || []
      variant = @context['variant'] || @context[:variant]
      product = @context['product'] || @context[:product]
      client_incases = @context['incases'] || @context[:incases]

      webform = @context['webform'] || incase&.webform

      liquid_context = Automation::LiquidContextBuilder.build(
        incase: incase,
        client: recipient,
        client_incases: client_incases,
        webform: webform,
        variants: variants,
        variant: variant,
        product: product
      )

      rendered_subject = template.subject.present? ? render_liquid(template.subject, liquid_context) : nil
      rendered_content = render_liquid(template.content, liquid_context)

      message = @account.automation_messages.create!(
        automation_rule: @action.automation_rule,
        automation_action: @action,
        client: recipient,
        incase: incase,
        channel: 'sms',
        status: 'pending',
        subject: rendered_subject,
        content: rendered_content
      )

      idgtl_settings = @account.idgtl
      unless idgtl_settings
        message.update!(status: 'failed', error_message: 'i-dgtl is not configured for this account')
        return
      end

      client = SmsProviders::IdgtlClient.new(token_1: idgtl_settings.token_1)
      result = client.send_sms!(
        sender_name: idgtl_settings.sender_name,
        destination: recipient.phone,
        content: rendered_content,
        external_message_id: message.id.to_s
      )

      message.update!(
        status: 'sent',
        sent_at: Time.current,
        provider: 'idgtl',
        message_id: result[:message_uuid].presence,
        x_track_id: result[:external_message_id].presence || message.id.to_s
      )
    rescue SmsProviders::IdgtlClient::ApiError => e
      message.update!(status: 'failed', error_message: "i-dgtl error (#{e.http_status}): #{e.raw}")
    rescue => e
      message.update!(status: 'failed', error_message: e.message.to_s)
      Rails.logger.error "Failed to send automation sms via i-dgtl: #{e.message}"
    end

    def send_sms_moizvonki
      template_id = @action.template_id
      template = @account.message_templates.find_by(id: template_id)
      return unless template

      recipient = @context['client'] || @context[:client]
      return unless recipient&.phone.present?

      incase = @context['incase'] || @context[:incase]
      variants = @context['variants'] || []
      variant = @context['variant'] || @context[:variant]
      product = @context['product'] || @context[:product]
      client_incases = @context['incases'] || @context[:incases]

      webform = @context['webform'] || incase&.webform

      liquid_context = Automation::LiquidContextBuilder.build(
        incase: incase,
        client: recipient,
        client_incases: client_incases,
        webform: webform,
        variants: variants,
        variant: variant,
        product: product
      )

      rendered_subject = template.subject.present? ? render_liquid(template.subject, liquid_context) : nil
      rendered_content = render_liquid(template.content, liquid_context)

      message = @account.automation_messages.create!(
        automation_rule: @action.automation_rule,
        automation_action: @action,
        client: recipient,
        incase: incase,
        channel: 'sms',
        status: 'pending',
        subject: rendered_subject,
        content: rendered_content
      )

      moizvonki_settings = @account.moizvonki
      unless moizvonki_settings
        message.update!(status: 'failed', error_message: 'Moizvonki is not configured for this account')
        return
      end

      client = SmsProviders::MoizvonkiClient.new(
        domain: moizvonki_settings.domain,
        user_name: moizvonki_settings.user_name,
        api_key: moizvonki_settings.api_key
      )
      client.send_sms!(to: recipient.phone, text: rendered_content)

      message.update!(
        status: 'sent',
        sent_at: Time.current,
        provider: 'moizvonki',
        x_track_id: message.id.to_s
      )
    rescue SmsProviders::MoizvonkiClient::ApiError => e
      message.update!(status: 'failed', error_message: "Moizvonki error (#{e.http_status}): #{e.raw}")
    rescue => e
      message.update!(status: 'failed', error_message: e.message.to_s)
      Rails.logger.error "Failed to send automation sms via Moizvonki: #{e.message}"
    end

    def send_email_to_users
      template_id = @action.template_id
      template = @account.message_templates.find_by(id: template_id)
      return unless template

      # Получаем заявку из контекста
      incase = @context['incase'] || @context[:incase]
      return unless incase

      webform = @context['webform'] || incase&.webform
      client = @context['client'] || @context[:client]
      
      # variant и product передаются из контекста (для события variant.back_in_stock)
      variant = @context['variant'] || @context[:variant]
      product = @context['product'] || @context[:product]

      # Получаем всех пользователей аккаунта
      users = @account.users.includes(:account_users)

      users.each do |user|
        next unless user.email_address.present?

        # Строим контекст для Liquid
        liquid_context = Automation::LiquidContextBuilder.build(
          incase: incase,
          client: client,
          webform: webform,
          variant: variant,
          product: product,
          user: user,
          account: @account
        )

        rendered_subject = render_liquid(template.subject, liquid_context)
        rendered_content = render_liquid(template.content, liquid_context)

        # Создаем запись AutomationMessage
        message = @account.automation_messages.create!(
          automation_rule: @action.automation_rule,
          automation_action: @action,
          user: user,
          client: nil,
          incase: incase,
          channel: 'email',
          status: 'pending',
          subject: rendered_subject,
          content: rendered_content
        )

        # Отправляем email через Mailganer
        send_email_via_mailganer(message, user.email_address, rendered_subject, rendered_content)
      end
    end

    def send_telegram
      template_id = @action.template_id
      template = @account.message_templates.find_by(id: template_id)
      return unless template

      recipient = @context['client'] || @context[:client]
      return unless recipient

      # Проверяем, что у клиента есть telegram_chat_id или telegram_username или phone
      unless recipient.telegram_chat_id.present? || recipient.telegram_username.present? || recipient.phone.present?
        Rails.logger.warn "Client ##{recipient.id} has no Telegram contact information"
        return
      end

      incase = @context['incase'] || @context[:incase]
      variants = @context['variants'] || []
      variant = @context['variant'] || @context[:variant]
      product = @context['product'] || @context[:product]
      client_incases = @context['incases'] || @context[:incases]

      webform = @context['webform'] || incase&.webform

      liquid_context = Automation::LiquidContextBuilder.build(
        incase: incase,
        client: recipient,
        client_incases: client_incases,
        webform: webform,
        variants: variants,
        variant: variant,
        product: product
      )

      rendered_content = render_liquid(template.content, liquid_context)

      message = @account.automation_messages.create!(
        automation_rule: @action.automation_rule,
        automation_action: @action,
        client: recipient,
        incase: incase,
        channel: 'telegram',
        status: 'pending',
        content: rendered_content
      )

      sender = TelegramProviders::MessageSender.new(account: @account)
      result = sender.send(client: recipient, text: rendered_content)

      if result[:ok]
        message.update!(
          status: 'sent',
          sent_at: Time.current,
          message_id: result[:message_id].to_s,
          provider: result[:channel]
        )
      else
        message.update!(
          status: 'failed',
          error_message: result[:error] || "Unknown error"
        )
        Rails.logger.error "Failed to send automation telegram: #{result[:error]}"
      end
    rescue => e
      message&.update!(status: 'failed', error_message: e.message.to_s)
      Rails.logger.error "Failed to send automation telegram: #{e.message}"
    end

    def change_status
      new_status = @action.status
      incase = @context['incase']
      return unless incase && new_status.present?

      incase.update!(status: new_status)
      Rails.logger.info "Changed incase ##{incase.id} status to #{new_status}"
    end

    def render_liquid(content, liquid_context)
      return '' if content.blank?
      template = Liquid::Template.parse(content)
      template.render(liquid_context, { strict_variables: false })
    rescue Liquid::Error => e
      Rails.logger.error "Liquid render error: #{e.message}"
      content
    end
  end
end
