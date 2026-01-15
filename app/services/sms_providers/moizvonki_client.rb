require "net/http"

module SmsProviders
  class MoizvonkiClient
    def initialize(domain:, user_name:, api_key:)
      @domain = domain
      @user_name = user_name
      @api_key = api_key
    end

    def send_sms!(to:, text:)
      uri = URI.parse("https://#{@domain}.moizvonki.ru/api/v1")

      # По доке REST требуется Content-Type: application/json, но пример отправляет
      # параметр request_data, содержащий JSON-строку.
      # Делаем совместимый вариант: JSON body с request_data (string).
      request_data = {
        user_name: @user_name,
        api_key: @api_key,
        action: "calls.send_sms",
        to: to,
        text: text
      }

      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req.body = { request_data: request_data.to_json }.to_json

      res = http_for(uri).request(req)
      body = parse_json(res.body)

      return { ok: true, raw: body } if res.code.to_i == 200

      raise ApiError.new("Moizvonki API error", http_status: res.code.to_i, raw: body)
    end

    class ApiError < StandardError
      attr_reader :http_status, :raw

      def initialize(message, http_status:, raw:)
        super(message)
        @http_status = http_status
        @raw = raw
      end
    end

    private

    def http_for(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.read_timeout = 15
      http.open_timeout = 10
      http
    end

    def parse_json(str)
      JSON.parse(str.to_s)
    rescue JSON::ParserError
      str.to_s
    end
  end
end

