require 'telegram/bot'

module TelegramProviders
  class BotClient
    def initialize(token:)
      @token = token
      @client = Telegram::Bot::Client.new(@token)
    end

    # Отправка сообщения через бота
    # @param chat_id [String, Integer] ID чата
    # @param text [String] Текст сообщения
    # @return [Hash] Результат отправки с message_id
    def send_message(chat_id:, text:)
      response = @client.api.send_message(
        chat_id: chat_id,
        text: text
      )
      {
        ok: true,
        message_id: response['result']['message_id'],
        chat_id: response['result']['chat']['id'],
        raw: response
      }
    rescue Telegram::Bot::Exceptions::ResponseError => e
      {
        ok: false,
        error: e.message,
        error_code: e.error_code,
        raw: e.response
      }
    rescue => e
      {
        ok: false,
        error: e.message
      }
    end

    # Проверка подписки клиента на бота
    # @param chat_id [String, Integer] ID чата
    # @param user_id [String, Integer] ID пользователя
    # @return [Boolean] true если пользователь подписан на бота
    def get_chat_member(chat_id:, user_id:)
      response = @client.api.get_chat_member(
        chat_id: chat_id,
        user_id: user_id
      )
      status = response['result']['status']
      # Статусы: creator, administrator, member, restricted, left, kicked
      %w[creator administrator member restricted].include?(status)
    rescue Telegram::Bot::Exceptions::ResponseError => e
      Rails.logger.error "Telegram Bot get_chat_member error: #{e.message}"
      false
    rescue => e
      Rails.logger.error "Telegram Bot get_chat_member error: #{e.message}"
      false
    end

    # Установка webhook для бота
    # @param url [String] URL для webhook
    # @param secret_token [String] Секретный токен для верификации
    # @return [Hash] Результат установки
    def set_webhook(url:, secret_token:)
      response = @client.api.set_webhook(
        url: url,
        secret_token: secret_token
      )
      {
        ok: response['ok'],
        raw: response
      }
    rescue Telegram::Bot::Exceptions::ResponseError => e
      {
        ok: false,
        error: e.message,
        error_code: e.error_code,
        raw: e.response
      }
    rescue => e
      {
        ok: false,
        error: e.message
      }
    end

    # Удаление webhook
    def delete_webhook
      response = @client.api.delete_webhook
      {
        ok: response['ok'],
        raw: response
      }
    rescue => e
      {
        ok: false,
        error: e.message
      }
    end

    # Получение информации о боте
    def get_me
      response = @client.api.get_me
      {
        ok: response['ok'],
        bot_info: response['result'],
        raw: response
      }
    rescue => e
      {
        ok: false,
        error: e.message
      }
    end
  end
end
