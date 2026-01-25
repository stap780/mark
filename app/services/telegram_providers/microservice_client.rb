module TelegramProviders
  class MicroserviceClient
    def initialize(account:)
      @account = account
      @http_client = Faraday.new(url: base_url) do |conn|
        conn.request :json
        conn.response :json
        conn.adapter Faraday.default_adapter
        conn.options.timeout = 30
      end
    end

    # Отправка кода авторизации
    def send_code(phone:)
      response = @http_client.post('/api/v1/auth/send_code') do |req|
        req.headers['X-Account-Id'] = @account.id.to_s
        req.body = { phone: phone }
      end
      handle_response(response)
    rescue => e
      Rails.logger.error "MicroserviceClient send_code error: #{e.message}"
      { ok: false, error: e.message }
    end

    # Верификация кода
    def verify_code(phone:, code:, phone_code_hash:, password: nil)
      response = @http_client.post('/api/v1/auth/verify') do |req|
        req.headers['X-Account-Id'] = @account.id.to_s
        req.body = {
          phone: phone,
          code: code,
          phone_code_hash: phone_code_hash,
          password: password
        }.compact
      end
      handle_response(response)
    rescue => e
      Rails.logger.error "MicroserviceClient verify_code error: #{e.message}"
      { ok: false, error: e.message }
    end

    # Отправка сообщения
    def send_message(recipient:, text:)
      Rails.logger.info "MicroserviceClient sending message to #{recipient} via #{base_url}/api/v1/messages/send"
      
      response = @http_client.post('/api/v1/messages/send') do |req|
        req.headers['X-Account-Id'] = @account.id.to_s
        req.body = {
          recipient: recipient,
          text: text
        }
      end
      
      Rails.logger.info "MicroserviceClient response status: #{response.status}, body: #{response.body.inspect}"
      handle_response(response)
    rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, SocketError => e
      Rails.logger.error "MicroserviceClient send_message connection error: #{e.message}"
      Rails.logger.error "Attempted URL: #{base_url}"
      Rails.logger.error "Check if TELEGRAM_MICROSERVICE_URL is set or microservice is running"
      { ok: false, error: "Сервис Telegram временно недоступен. Проверьте настройки микросервиса." }
    rescue => e
      Rails.logger.error "MicroserviceClient send_message error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { ok: false, error: "Ошибка отправки через Telegram: #{e.message}" }
    end

    # Получение статуса сессии
    def session_status
      response = @http_client.get("/api/v1/sessions/#{@account.id}/status")
      handle_response(response)
    rescue => e
      Rails.logger.error "MicroserviceClient session_status error: #{e.message}"
      { ok: false, error: e.message }
    end

    # Очистка сессии
    def clear_session
      response = @http_client.delete("/api/v1/sessions/#{@account.id}")
      handle_response(response)
    rescue => e
      Rails.logger.error "MicroserviceClient clear_session error: #{e.message}"
      { ok: false, error: e.message }
    end

    private

    def base_url
      @base_url ||= begin
        # В development всегда используем localhost, без проверки ENV и credentials
        if Rails.env.development?
          url = 'http://localhost:8000'
          Rails.logger.info "Telegram Microservice URL: #{url} (env: development, default)"
          return url
        end
        
        # В production используем только credentials
        url = Rails.application.credentials.dig(:telegram, :microservice_url)
        if url.blank?
          Rails.logger.error "Telegram Microservice URL not configured in credentials for production!"
          raise "Telegram Microservice URL must be configured in Rails credentials for production"
        end
        Rails.logger.info "Telegram Microservice URL: #{url} (env: #{Rails.env}, source: credentials)"
        url
      end
    end

    def handle_response(response)
      # Проверяем и HTTP статус, и поле 'ok' в теле ответа
      body = response.body
      is_success = response.success? && (body.is_a?(Hash) ? body['ok'] != false : true)
      
      if is_success
        Rails.logger.info "MicroserviceClient successful response: #{body.inspect}"
        { ok: true, data: body }
      else
        error_message = if body.is_a?(Hash)
                          body['error'] || body['detail'] || 'Unknown error'
                        else
                          'Unknown error'
                        end
        Rails.logger.error "MicroserviceClient error response (status #{response.status}): #{error_message}, body: #{body.inspect}"
        { ok: false, error: error_message }
      end
    end
  end
end
