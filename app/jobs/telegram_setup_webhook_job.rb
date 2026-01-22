class TelegramSetupWebhookJob < ApplicationJob
  queue_as :default

  def perform(telegram_setup_id)
    telegram_setup = TelegramSetup.find_by(id: telegram_setup_id)
    return unless telegram_setup&.bot_token.present?

    telegram_setup.setup_webhook
  rescue => e
    Rails.logger.error "Ошибка установки webhook для TelegramSetup ##{telegram_setup_id}: #{e.message}"
    # Не поднимаем исключение, чтобы не ломать сохранение записи
  end
end
