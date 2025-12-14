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
    settings = {
      address: address,
      port: port.to_i,
      domain: domain,
      user_name: user_name,
      password: user_password,
      authentication: authentication.to_sym,
      enable_starttls_auto: tls?,
      # Увеличиваем таймауты для медленных SMTP серверов
      open_timeout: 30,      # Таймаут установки соединения (секунды)
      read_timeout: 120,     # Таймаут чтения ответа (секунды) - увеличен с дефолтных 60
      write_timeout: 30      # Таймаут записи данных (секунды)
    }
    settings
  end

  def has_smtp_settings?
    address.present? && port.present? && user_name.present? && user_password.present?
  end

  # Проверка доступности SMTP сервера
  def test_smtp_connection
    return [false, "SMTP settings are incomplete"] unless has_smtp_settings?

    begin
      require 'net/smtp'
      require 'timeout'

      Timeout.timeout(10) do
        smtp = Net::SMTP.new(address, port.to_i)
        smtp.open_timeout = 10  # Таймаут установки соединения
        smtp.read_timeout = 10  # Таймаут чтения ответа
        
        smtp.start(domain) do |s|
          s.authenticate(user_name, user_password, authentication.to_sym)
        end
        
        [true, "SMTP server is reachable and authentication successful"]
      end
    rescue Timeout::Error
      [false, "Connection timeout: SMTP server did not respond in time"]
    rescue Net::SMTPAuthenticationError => e
      [false, "Authentication failed: #{e.message}"]
    rescue Net::SMTPError => e
      [false, "SMTP error: #{e.message}"]
    rescue Errno::ECONNREFUSED
      [false, "Connection refused: SMTP server is not reachable on #{address}:#{port}"]
    rescue SocketError => e
      [false, "Network error: #{e.message}"]
    rescue => e
      [false, "Connection test failed: #{e.message}"]
    end
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

