require "mailganer_client"

MailganerClient.configure do |config|
    config.api_key = Rails.application.credentials.dig(:mailganer, :api_key)
    config.smtp_login = Rails.application.credentials.dig(:mailganer, :smtp_login)
    config.api_key_web_portal = Rails.application.credentials.dig(:mailganer, :api_key_web_portal)
end

# Патч для отключения проверки SSL (только для development)
if Rails.env.development?
  module MailganerClient
    class Client
      def request(method, endpoint, data = nil, without_content_type = false)
        uri = URI.join(@host, endpoint)

        if (method.upcase == 'GET' && data)
          uri.query = URI.encode_www_form(data)
        end

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # Отключаем проверку SSL
        http.read_timeout = 10

        req = case method.upcase
              when 'GET' then Net::HTTP::Get.new(uri)
              when 'POST' then Net::HTTP::Post.new(uri)
              else raise ApiError, "Unsupported method #{method}"
              end

        if !without_content_type
          req['Content-Type'] = 'application/json'
        end
        req['Authorization'] = @api_key
        req['Mg-Api-Key'] = @api_key_web_portal

        req.body = data.to_json if data

        if (@debug)
          puts "==== HTTP DEBUG ===="
          puts "Method: #{method.upcase}"
          puts "URL: #{uri}"
          puts "Headers: #{req.each_header.to_h}"
          puts "Body: #{req.body}" if req.body
          puts "==================="
        end

        begin
          res = http.request(req)
        rescue Timeout::Error
          raise ApiError, 'Request timed out'
        rescue SocketError => e
          raise ApiError, e&.message
        end

        json = JSON.parse(res.body, symbolize_names: true)

        unless res.code.to_i == 200 && json[:status].to_s.downcase == "ok"
          message = json[:message] || "API error"

          if message.include?("550 bounced check filter")
            raise StopListError, message
          elsif message.include?("from domain not trusted")
            raise DomainNotTrustedError, message
          elsif res.code.to_i == 403
            raise AuthorizationError, message
          elsif res.code.to_i == 400
            raise BadRequestError, message
          else
            raise ApiError, message
          end
        end

        json
      end
    end
  end
end

# Расширяем MailganerClient::Client для поддержки кастомного x_track_id
module MailganerClient
  class Client
    # Переопределяем метод send_email_smtp_v1, добавляя опциональный параметр x_track_id
    def send_email_smtp_v1(type:, to:, subject:, body: nil, from:, name_from: nil, template_id: nil, params: nil, attach_files: [], x_track_id: nil)
      validate_email!(to)
      validate_email!(from)

      data = {
        email_to: to,
        subject: subject,
        params: params,
        check_local_stop_list: true,
        track_open: true,
        track_click: true,
        email_from: name_from ? "#{name_from} <#{from}>" : from,
        attach_files: attach_files,
        # Используем переданный x_track_id или дефолтное значение из библиотеки
        x_track_id: x_track_id || "#{@smtp_login}-#{Time.now.to_i}-#{SecureRandom.hex(6)}",
      }

      case type
      when 'template'
        data[:template_id] = template_id
      when 'body'
        data[:message_text] = body
      else
        raise ApiError, "Unsupported type #{type}; select type = template or type = body"
      end

      request('POST', "api/v1/smtp_send?key=#{@api_key}", data)
    end
  end
end
