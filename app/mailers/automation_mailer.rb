class AutomationMailer < ApplicationMailer
  after_action :set_delivery_options

  def notify_client(template, client, context)
    @template = template
    @client = client
    @context = context

    # Получаем email_setup из аккаунта шаблона или из текущего контекста
    account = template.account || Account.current
    @email_setup = account&.email_setup

    # Рендерим Liquid шаблон
    @subject = render_liquid(template.subject, context)
    @content = render_liquid(template.content, context)

    # Определяем отправителя
    from_email = @email_setup&.user_name || default_from_email

    mail(
      to: client.email,
      from: from_email,
      subject: @subject
    )
  end

  private

  def set_delivery_options
    if @email_setup&.has_smtp_settings?
      mail.delivery_method.settings.merge!(@email_setup.smtp_settings)
    end
  end

  def default_from_email
    "from@example.com"
  end

  def render_liquid(content, context)
    return '' if content.blank?
    template = Liquid::Template.parse(content)
    template.render(context.deep_stringify_keys)
  rescue Liquid::Error => e
    Rails.logger.error "Liquid render error in mailer: #{e.message}"
    content
  end
end

