class Api::TelegramWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_webhook_secret

  def incoming_message
    # account_id и message приходят в body запроса от микросервиса (JSON)
    request_body = request.body.read
    json_data = JSON.parse(request_body) rescue {}
    
    account_id = json_data['account_id']&.to_i
    message_data = json_data['message']
    
    return head :bad_request unless account_id && message_data
    
    account = Account.find_by(id: account_id)
    return head :not_found unless account

    # Обработка входящего сообщения
    ProcessIncomingTelegramMessageJob.perform_later(
      account_id: account_id,
      message: message_data
    )

    head :ok
  end

  private

  def verify_webhook_secret
    secret = request.headers['X-Webhook-Secret']
    expected = ENV['TELEGRAM_MICROSERVICE_SECRET'] || 
               Rails.application.credentials.dig(:telegram, :webhook_secret)
    
    unless expected && ActiveSupport::SecurityUtils.secure_compare(secret.to_s, expected.to_s)
      head :unauthorized
    end
  end
end
