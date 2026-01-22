class TelegramSetup < ApplicationRecord
  include AccountScoped

  belongs_to :account

  validates :account_id, uniqueness: true
  validates :webhook_secret, presence: true

  before_validation :ensure_webhook_secret
  after_save :setup_webhook_after_save, if: -> { saved_change_to_bot_token? && bot_token.present? }

  # Проверяет, настроен ли бот (есть токен)
  def bot_configured?
    bot_token.present?
  end

  # Проверяет, авторизован ли личный аккаунт
  def personal_authorized?
    personal_authorized && personal_session.present?
  end

  # Установка webhook для бота
  # @param base_url [String, nil] Базовый URL приложения. Если не указан, берется из ENV/credentials
  # @return [Hash] Результат установки { ok: true/false, error: ... }
  def setup_webhook(base_url: nil)
    return { ok: false, error: 'Bot token отсутствует' } unless bot_token.present?

    base_url ||= application_base_url
    webhook_url = "#{base_url}/api/webhooks/telegram/#{account_id}/#{webhook_secret}"

    bot_client = TelegramProviders::BotClient.new(token: bot_token)
    result = bot_client.set_webhook(
      url: webhook_url,
      secret_token: webhook_secret
    )

    if result[:ok]
      Rails.logger.info "Webhook установлен для account ##{account_id}: #{webhook_url}"
    else
      Rails.logger.error "Ошибка установки webhook для account ##{account_id}: #{result[:error]}"
    end

    result
  end

  private

  def ensure_webhook_secret
    self.webhook_secret = SecureRandom.hex(16) if webhook_secret.blank?
  end

  def setup_webhook_after_save
    # Выполняем в фоне, чтобы не блокировать сохранение
    TelegramSetupWebhookJob.perform_later(id)
  end

  def application_base_url
    ENV['APP_URL'] ||
      Rails.application.credentials.dig(:app, :url) ||
      default_base_url
  end

  def default_base_url
    if Rails.env.development?
      'http://localhost:3000'
    elsif Rails.env.production?
      # В production должен быть установлен APP_URL или в credentials
      'https://example.com' # fallback, но лучше установить APP_URL
    else
      'http://localhost:3000'
    end
  end
end
