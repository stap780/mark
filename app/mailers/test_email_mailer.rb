class TestEmailMailer < ApplicationMailer
  before_action :set_email_setup
  after_action :set_delivery_options

  def test_email(email_setup, to_email)
    @email_setup = email_setup
    @to_email = to_email

    mail(
      to: to_email,
      from: email_setup.user_name,
      subject: "Test Email from Mark"
    )
  end

  private

  def set_email_setup
    # Email setup уже передан в параметрах
  end

  def set_delivery_options
    if @email_setup&.has_smtp_settings?
      mail.delivery_method.settings.merge!(@email_setup.smtp_settings)
    end
  end
end

