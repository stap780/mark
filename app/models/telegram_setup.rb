class TelegramSetup < ApplicationRecord
  include AccountScoped

  belongs_to :account

  validates :account_id, uniqueness: true
  validates :webhook_secret, presence: true

  before_validation :ensure_webhook_secret
  after_save :setup_webhook_after_save, if: -> { saved_change_to_bot_token? && bot_token.present? }
  before_destroy :clear_personal_session

  # Проверяет, настроен ли бот (есть токен)
  def bot_configured?
    bot_token.present?
  end

  # Проверяет, авторизован ли личный аккаунт
  def personal_authorized?
    personal_authorized && personal_session.present?
  end

  # Имя бота из Telegram API (@"username" или first_name), с мемоизацией на время запроса
  def bot_display_name
    return nil unless bot_token.present?
    @bot_display_name ||= fetch_bot_display_name
  end

  # Установка webhook для бота (localhost:3000 в dev, app.teletri.ru в prod)
  # @return [Hash] Результат установки { ok: true/false, error: ... }
  def setup_webhook
    return { ok: false, error: 'Bot token отсутствует' } unless bot_token.present?

    webhook_url = "#{application_base_url}/api/webhooks/telegram/#{account_id}/#{webhook_secret}"

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

  def clear_personal_session
    # Очищаем сессию в микросервисе перед удалением записи
    if personal_authorized?
      microservice = TelegramProviders::MicroserviceClient.new(account: account)
      result = microservice.clear_session
      
      if result[:ok]
        Rails.logger.info "Сессия Telegram очищена для account ##{account_id}"
      else
        Rails.logger.error "Ошибка очистки сессии Telegram для account ##{account_id}: #{result[:error]}"
      end
    end
  rescue => e
    # Не блокируем удаление, если очистка сессии не удалась
    Rails.logger.error "Ошибка при очистке сессии Telegram перед удалением: #{e.message}"
  end

  def application_base_url
    Rails.env.development? ? 'http://localhost:3000' : 'https://app.teletri.ru'
  end

  def fetch_bot_display_name
    result = TelegramProviders::BotClient.new(token: bot_token).get_me
    return nil unless result[:ok]
    info = result[:bot_info]
    return nil if info.blank?
    username = info.is_a?(Hash) ? info['username'] : info.try(:username)
    name = info.is_a?(Hash) ? info['first_name'] : info.try(:first_name)
    if username.present?
      username.to_s.start_with?('@') ? username.to_s : "@#{username}"
    elsif name.present?
      name.to_s
    end
  rescue => e
    Rails.logger.warn "TelegramSetup#bot_display_name failed: #{e.message}"
    nil
  end
end
