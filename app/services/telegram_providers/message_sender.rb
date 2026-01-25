module TelegramProviders
  class MessageSender
    def initialize(account:)
      @account = account
      @telegram_setup = account.telegram_setup
    end

    # Отправка сообщения клиенту
    # Определяет канал (бот/личный) и отправляет сообщение
    # Приоритет: сначала пытаемся через бота (если есть telegram_chat_id),
    # при ошибке - fallback на персональный аккаунт
    # @param client [Client] Клиент для отправки
    # @param text [String] Текст сообщения
    # @return [Hash] Результат отправки с message_id и каналом
    def send(client:, text:)
      return error_result("Telegram не настроен для этого аккаунта") unless @telegram_setup

      # Если бот настроен и у клиента есть telegram_chat_id, пытаемся отправить через бота
      if bot_available? && client.telegram_chat_id.present?
        bot_result = send_via_bot(client: client, text: text)
        
        # Если отправка через бота успешна - возвращаем результат
        return bot_result if bot_result[:ok]
        
        # Если ошибка связана с тем, что клиент не подписан/заблокировал бота,
        # пытаемся отправить через персональный аккаунт
        if should_fallback_to_personal?(bot_result) && personal_account_authorized?
          Rails.logger.info "Bot send failed for client ##{client.id}, falling back to personal account. Error: #{bot_result[:error]}"
          return send_via_personal(client: client, text: text)
        end
        
        # Если fallback не возможен, возвращаем ошибку бота
        return bot_result
      end
      
      # Если бот не доступен или нет telegram_chat_id, используем персональный аккаунт
      if personal_account_authorized?
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

    # Определяет, нужно ли делать fallback на персональный аккаунт
    # при ошибке отправки через бота
    # @param bot_result [Hash] Результат отправки через бота
    # @return [Boolean] true если нужно попробовать персональный аккаунт
    def should_fallback_to_personal?(bot_result)
      return false unless bot_result.is_a?(Hash) && !bot_result[:ok]
      
      error = bot_result[:error].to_s.downcase
      error_code = bot_result[:error_code]
      
      # Ошибки, которые означают, что клиент не подписан/заблокировал бота
      # и стоит попробовать персональный аккаунт
      fallback_errors = [
        'chat not found',
        'user not found',
        'bot was blocked by the user',
        'bot blocked',
        'chat_id is empty',
        'bad request: chat not found',
        'forbidden: bot was blocked by the user',
        'forbidden: user is deactivated'
      ]
      
      # Проверяем по тексту ошибки
      return true if fallback_errors.any? { |fallback_error| error.include?(fallback_error) }
      
      # Проверяем по коду ошибки (400 - bad request, 403 - forbidden)
      return true if error_code.in?([400, 403])
      
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
          error: result[:error] || "Неизвестная ошибка",
          error_code: result[:error_code]
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

      Rails.logger.info "Sending message via personal account to recipient: #{recipient}, text length: #{text.length}"

      # Используем микросервис
      microservice = TelegramProviders::MicroserviceClient.new(account: @account)
      result = microservice.send_message(recipient: recipient, text: text)
      
      Rails.logger.info "Microservice result: ok=#{result[:ok]}, error=#{result[:error]}, data=#{result[:data].inspect}"
      
      if result[:ok]
        {
          ok: true,
          channel: 'personal',
          message_id: result[:data]['message_id'],
          recipient: recipient
        }
      else
        # Улучшаем сообщение об ошибке для пользователя
        error_message = result[:error] || "Неизвестная ошибка"
        
        # Если ошибка связана с тем, что контакт не найден
        if error_message.include?("Cannot find any entity") || error_message.include?("not found")
          if recipient.start_with?('+') || recipient.match?(/^\d/)
            error_message = "Контакт с номером #{recipient} не найден в Telegram. Убедитесь, что контакт добавлен в ваши контакты Telegram и номер указан правильно."
          else
            error_message = "Контакт #{recipient} не найден в Telegram. Убедитесь, что username указан правильно или контакт добавлен в ваши контакты."
          end
        end
        
        {
          ok: false,
          channel: 'personal',
          error: error_message
        }
      end
    rescue => e
      Rails.logger.error "Error sending message via microservice: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
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
