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
      when 'change_status'
        change_status
      else
        Rails.logger.warn "Unknown action kind: #{@action.kind}"
      end
    end

    private

    def send_email
      template_id = @action.settings['template_id']
      template = @account.message_templates.find_by(id: template_id)
      return unless template

      client = @context['client']
      return unless client&.email.present?

      # Создаем запись для статистики
      message = @account.automation_messages.create!(
        automation_rule: @action.automation_rule,
        automation_action: @action,
        client: client,
        incase: @context['incase'],
        channel: 'email',
        status: 'pending',
        subject: render_liquid(template.subject, @context),
        content: render_liquid(template.content, @context)
      )

      begin
        # Устанавливаем контекст аккаунта для AutomationMailer
        Account.current = @account
        
        # Отправляем email
        AutomationMailer.notify_client(template, client, @context).deliver_later

        message.update!(
          status: 'sent',
          sent_at: Time.current
        )
      rescue => e
        message.update!(
          status: 'failed',
          error_message: e.message
        )
        Rails.logger.error "Failed to send automation email: #{e.message}"
      end
    end

    def change_status
      new_status = @action.settings['status']
      incase = @context['incase']
      return unless incase && new_status.present?

      incase.update!(status: new_status)
    end

    def render_liquid(content, context)
      return '' if content.blank?
      template = Liquid::Template.parse(content)
      template.render(context.deep_stringify_keys)
    rescue Liquid::Error => e
      Rails.logger.error "Liquid render error: #{e.message}"
      content
    end
  end
end

