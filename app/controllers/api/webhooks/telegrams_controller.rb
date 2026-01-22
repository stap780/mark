class Api::Webhooks::TelegramsController < ApplicationController
  skip_before_action :require_authentication, raise: false
  skip_before_action :verify_authenticity_token

  def update
    account = Account.find(params[:account_id])
    settings = account.telegram_setup
    return head :unprocessable_entity unless settings
    return head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(settings.webhook_secret.to_s, params[:secret].to_s)

    payload = request.request_parameters
    update_data = payload.respond_to?(:to_unsafe_h) ? payload.to_unsafe_h : payload

    # Обрабатываем только сообщения (message updates)
    return head :ok unless update_data["message"].present?

    message_data = update_data["message"]
    chat = message_data["chat"]
    from = message_data["from"]

    return head :ok unless chat && from

    chat_id = chat["id"].to_s
    user_id = from["id"].to_s
    username = from["username"]
    text = message_data["text"]

    # Находим или создаем клиента по telegram_chat_id или username
    client = find_or_create_client(account: account, chat_id: chat_id, user_id: user_id, username: username)

    # Сохраняем telegram_chat_id и username если их еще нет
    if client.telegram_chat_id.blank?
      client.update_column(:telegram_chat_id, chat_id)
    end
    if username.present? && client.telegram_username.blank?
      client.update_column(:telegram_username, "@#{username}")
    end

    # TODO: Здесь можно добавить обработку входящих сообщений от клиентов
    # Например, сохранение в историю переписки или автоматический ответ

    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue => e
    raise e if Rails.env.test?
    Rails.logger.error("Telegram webhook error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    head :internal_server_error
  end

  private

  def find_or_create_client(account:, chat_id:, user_id:, username:)
    # Сначала пытаемся найти по telegram_chat_id
    client = account.clients.find_by(telegram_chat_id: chat_id)
    return client if client

    # Пытаемся найти по username
    if username.present?
      client = account.clients.find_by(telegram_username: "@#{username}")
      return client if client
    end

    # Создаем нового клиента
    account.clients.create!(
      name: username || "Telegram User",
      telegram_chat_id: chat_id,
      telegram_username: username.present? ? "@#{username}" : nil
    )
  end
end
