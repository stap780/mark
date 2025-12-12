class AutomationMailer < ApplicationMailer
  def notify_client(template, client, context)
    @template = template
    @client = client
    @context = context

    # Рендерим Liquid шаблон
    @subject = render_liquid(template.subject, context)
    @content = render_liquid(template.content, context)

    mail(
      to: client.email,
      subject: @subject
    )
  end

  private

  def render_liquid(content, context)
    return '' if content.blank?
    template = Liquid::Template.parse(content)
    template.render(context.deep_stringify_keys)
  rescue Liquid::Error => e
    Rails.logger.error "Liquid render error in mailer: #{e.message}"
    content
  end
end

