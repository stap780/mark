require "net/http"

module SmsProviders
  class IdgtlClient
    HOST = "https://direct.i-dgtl.ru".freeze

    def initialize(token_1:)
      @token_1 = token_1
    end

    def send_sms!(sender_name:, destination:, content:, external_message_id: nil)
      uri = URI.join(HOST, "/api/v1/message")

      payload = [
        {
          channelType: "SMS",
          senderName: sender_name,
          destination: destination,
          content: content,
          externalMessageId: external_message_id
        }.compact
      ]

      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Basic #{@token_1}"
      req["Content-Type"] = "application/json"
      req.body = payload.to_json

      res = http_for(uri).request(req)
      body = parse_json(res.body)

      if res.code.to_i == 200 && body.is_a?(Hash) && body["errors"] == false
        item = Array(body["items"]).first || {}
        return {
          ok: true,
          message_uuid: item["messageUuid"],
          external_message_id: item["externalMessageId"],
          code: item["code"],
          raw: body
        }
      end

      raise ApiError.new("i-dgtl API error", http_status: res.code.to_i, raw: body)
    end

    def get_message!(id:)
      uri = URI.join(HOST, "/api/v1/message/#{id}")
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Basic #{@token_1}"

      res = http_for(uri).request(req)
      body = parse_json(res.body)

      return { ok: true, raw: body, http_status: res.code.to_i } if res.code.to_i == 200

      { ok: false, raw: body, http_status: res.code.to_i }
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

