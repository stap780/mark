class EmailSetup < ApplicationRecord
  include AccountScoped
  belongs_to :account

  validates :account_id, uniqueness: true
  validates :address, presence: true
  validates :port, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :user_name, presence: true
  validates :user_password, presence: true
  validates :authentication, presence: true, inclusion: { in: %w[plain login cram_md5] }
  validates :domain, presence: true

  def smtp_settings
    {
      address: address,
      port: port.to_i,
      domain: domain,
      user_name: user_name,
      password: user_password,
      authentication: authentication.to_sym,
      enable_starttls_auto: tls?
    }
  end

  def has_smtp_settings?
    address.present? && port.present? && user_name.present? && user_password.present?
  end

  # Метод для отправки тестового письма через ActionMailer
  def send_test_email(to_email)
    return [false, "Email address is required"] unless to_email.present?
    return [false, "SMTP settings are incomplete"] unless has_smtp_settings?

    begin
      # Используем ActionMailer для отправки тестового письма
      TestEmailMailer.test_email(self, to_email).deliver_now
      [true, "Test email sent successfully"]
    rescue => e
      [false, "Failed to send test email: #{e.message}"]
    end
  end
end

