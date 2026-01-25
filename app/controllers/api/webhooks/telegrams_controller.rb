class Api::Webhooks::TelegramsController < ApplicationController
  skip_before_action :require_authentication, raise: false
  skip_before_action :verify_authenticity_token
  skip_before_action :set_locale
  skip_before_action :load_session
  skip_before_action :set_current_account
  skip_before_action :ensure_user_in_current_account
  skip_before_action :ensure_active_subscription

  # Обработка webhook от Telegram Bot API (когда клиент пишет боту)
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

    # Преобразуем формат Telegram Bot API в формат, который понимает ProcessIncomingTelegramMessageJob
    normalized_message = {
      "from_id" => user_id,
      "from_username" => username,
      "from_phone" => nil,
      "chat_id" => chat_id,
      "message_id" => message_data["message_id"],
      "text" => text,
      "date" => message_data["date"] ? Time.at(message_data["date"]).iso8601 : nil
    }

    # Используем общий job для обработки
    result = ProcessIncomingTelegramMessageJob.perform_now(
      account_id: account.id,
      message: normalized_message
    )

    if result
      Rails.logger.info "[Api::Webhooks::TelegramsController] Successfully processed bot message"
    else
      Rails.logger.warn "[Api::Webhooks::TelegramsController] Failed to process bot message"
    end

    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue => e
    raise e if Rails.env.test?
    Rails.logger.error("Telegram bot webhook error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    head :internal_server_error
  end

  # Обработка callback от микросервиса (когда клиент пишет в персональный аккаунт)
  def incoming_message
    # account_id и message приходят в body запроса от микросервиса (JSON)
    request_body = request.body.read
    json_data = JSON.parse(request_body) rescue {}
    
    message_id = json_data.dig('message', 'message_id')
    Rails.logger.info "[Api::Webhooks::TelegramsController] Received incoming message from microservice (message_id: #{message_id}): #{json_data.inspect}"
    
    # Секрет не проверяем, так как микросервис находится в той же Docker сети и недоступен извне
    
    account_id = json_data['account_id']&.to_i
    message_data = json_data['message']
    
    return head :bad_request unless account_id && message_data
    
    account = Account.find_by(id: account_id)
    return head :not_found unless account

    # Обрабатываем входящее сообщение синхронно для немедленного отображения
    result = ProcessIncomingTelegramMessageJob.perform_now(
      account_id: account_id,
      message: message_data
    )
    
    if result
      Rails.logger.info "[Api::Webhooks::TelegramsController] Successfully processed microservice message (message_id: #{message_id})"
    else
      Rails.logger.warn "[Api::Webhooks::TelegramsController] Failed to process microservice message (message_id: #{message_id})"
    end

    head :ok
  rescue => e
    Rails.logger.error "Telegram microservice webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    head :internal_server_error
  end

end
