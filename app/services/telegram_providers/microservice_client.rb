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
      response = @http_client.post('/api/v1/messages/send') do |req|
        req.headers['X-Account-Id'] = @account.id.to_s
        req.body = {
          recipient: recipient,
          text: text
        }
      end
      handle_response(response)
    rescue => e
      Rails.logger.error "MicroserviceClient send_message error: #{e.message}"
      { ok: false, error: e.message }
    end

    # Получение статуса сессии
    def session_status
      response = @http_client.get("/api/v1/sessions/#{@account.id}/status")
      handle_response(response)
    rescue => e
      Rails.logger.error "MicroserviceClient session_status error: #{e.message}"
      { ok: false, error: e.message }
    end

    private

    def base_url
      @base_url ||= ENV['TELEGRAM_MICROSERVICE_URL'] ||
                    Rails.application.credentials.dig(:telegram, :microservice_url) ||
                    default_url
    end

    def default_url
      # В development используем localhost, в production - имя контейнера
      if Rails.env.development?
        'http://localhost:8000'
      else
        'http://mark-telegram_service:8000'
      end
    end

    def handle_response(response)
      if response.success?
        { ok: true, data: response.body }
      else
        error_message = if response.body.is_a?(Hash)
                          response.body['detail'] || response.body['error'] || 'Unknown error'
                        else
                          'Unknown error'
                        end
        { ok: false, error: error_message }
      end
    end
  end
end
