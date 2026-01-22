class ProcessIncomingTelegramMessageJob < ApplicationJob
  queue_as :default

  def perform(account_id:, message:)
    account = Account.find_by(id: account_id)
    return unless account

    # TODO: Реализовать обработку входящего сообщения
    # - Найти или создать клиента по username/phone из message
    # - Сохранить сообщение в базу
    # - Триггерить Automation и т.д.
    
    Rails.logger.info "[ProcessIncomingTelegramMessageJob] Processing message for account ##{account_id}: #{message.inspect}"
    
    # Пример обработки (нужно адаптировать под структуру данных от микросервиса):
    # if message['from_username'] || message['from_phone']
    #   client = find_or_create_client(account, message)
    #   # Сохранить сообщение
    #   # Триггерить automation
    # end
  end
end
