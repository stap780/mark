class Api::Webhooks::MoizvonkisController < ApplicationController
  skip_before_action :require_authentication, raise: false
  skip_before_action :verify_authenticity_token

  def sms_message
    account = Account.find(params[:account_id])
    settings = account.moizvonki
    return head :unprocessable_entity unless settings
    return head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(settings.webhook_secret.to_s, params[:secret].to_s)

    payload = request.request_parameters
    payload_hash = payload.respond_to?(:to_unsafe_h) ? payload.to_unsafe_h : payload
    webhook = payload_hash["webhook"] || {}
    event = payload_hash["event"] || {}

    # We only handle outgoing sms.message events
    action = webhook["action"].to_s
    return head :ok unless action == "sms.message"

    direction = event["direction"].to_i
    event_type = event["event_type"].to_i
    return head :ok unless direction == 1 && event_type == 32

    client_number = normalize_phone(event["client_number"])
    text = event["text"].to_s.strip

    return head :ok if client_number.blank? || text.blank?

    candidate =
      account.automation_messages
             .joins(:automation_action)
             .includes(:client)
             .where(channel: "sms")
             .where(automation_actions: { kind: "send_sms_moizvonki" })
             .where(status: %w[pending sent])
             .where("sent_at IS NULL OR sent_at >= ?", 30.days.ago)
             .order(Arel.sql("COALESCE(automation_messages.sent_at, automation_messages.created_at) DESC"))
             .limit(200)
             .find do |m|
               normalize_phone(m.client&.phone) == client_number && m.content.to_s.strip == text
             end

    if candidate
      candidate.update!(
        status: "delivered",
        delivered_at: Time.current,
        provider_payload: payload_hash
      )
    end

    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue => e
    raise e if Rails.env.test?
    Rails.logger.error("Moizvonki webhook error: #{e.message}")
    head :internal_server_error
  end

  private

  def normalize_phone(value)
    value.to_s.gsub(/[^\d+]/, "").sub(/\A00/, "+").gsub(/\A\+?8/, "+7")
  end
end

