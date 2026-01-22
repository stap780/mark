module TelegramProviders
  class MessageSender
    def initialize(account:)
      @account = account
      @telegram_setup = account.telegram_setup
    end

    # Отправка сообщения клиенту
    # Определяет канал (бот/личный) и отправляет сообщение
    # @param client [Client] Клиент для отправки
    # @param text [String] Текст сообщения
    # @return [Hash] Результат отправки с message_id и каналом
    def send(client:, text:)
      return error_result("Telegram не настроен для этого аккаунта") unless @telegram_setup

      # Проверяем, подписан ли клиент на бота
      if bot_available? && client_subscribed_to_bot?(client)
        send_via_bot(client: client, text: text)
      elsif personal_account_authorized?
        send_via_personal(client: client, text: text)
      else
        error_result("Бот не настроен и личный аккаунт не авторизован")
      end
    end

    private

    def bot_available?
      @telegram_setup.bot_configured?
    end

    def personal_account_authorized?
      @telegram_setup.personal_authorized?
    end

    # Проверка подписки клиента на бота
    def client_subscribed_to_bot?(client)
      return false unless client.telegram_chat_id.present?

      bot_client = TelegramProviders::BotClient.new(token: @telegram_setup.bot_token)
      
      # Получаем user_id из chat_id (для приватных чатов chat_id == user_id)
      user_id = client.telegram_chat_id.to_i
      chat_id = client.telegram_chat_id

      bot_client.get_chat_member(chat_id: chat_id, user_id: user_id)
    rescue => e
      Rails.logger.error "Error checking bot subscription: #{e.message}"
      false
    end

    # Отправка через бота
    def send_via_bot(client:, text:)
      return error_result("У клиента нет telegram_chat_id") unless client.telegram_chat_id.present?

      bot_client = TelegramProviders::BotClient.new(token: @telegram_setup.bot_token)
      result = bot_client.send_message(chat_id: client.telegram_chat_id, text: text)

      if result[:ok]
        {
          ok: true,
          channel: 'bot',
          message_id: result[:message_id],
          chat_id: result[:chat_id]
        }
      else
        {
          ok: false,
          channel: 'bot',
          error: result[:error] || "Неизвестная ошибка"
        }
      end
    rescue => e
      {
        ok: false,
        channel: 'bot',
        error: e.message
      }
    end

    # Отправка через личный аккаунт
    def send_via_personal(client:, text:)
      # Определяем, отправлять по username или по телефону
      recipient = if client.telegram_username.present?
                    client.telegram_username
                  elsif client.phone.present?
                    normalize_phone(client.phone)
                  else
                    return error_result("У клиента нет telegram_username или phone")
                  end

      # Используем микросервис
      microservice = TelegramProviders::MicroserviceClient.new(account: @account)
      result = microservice.send_message(recipient: recipient, text: text)
      
      if result[:ok]
        {
          ok: true,
          channel: 'personal',
          message_id: result[:data]['message_id'],
          recipient: recipient
        }
      else
        {
          ok: false,
          channel: 'personal',
          error: result[:error]
        }
      end
    rescue => e
      Rails.logger.error "Error sending message via microservice: #{e.message}"
      {
        ok: false,
        channel: 'personal',
        error: e.message
      }
    end

    def normalize_phone(phone)
      phone.to_s.gsub(/[^\d+]/, "").sub(/\A00/, "+").gsub(/\A\+?8/, "+7")
    end

    def error_result(message)
      {
        ok: false,
        error: message
      }
    end
  end
end
