class AutomationMessagesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_automation_message, only: [:check_status]

  def index
    @search = current_account.automation_messages.ransack(params[:q])
    @search.sorts = "created_at desc" if @search.sorts.empty?
    @automation_messages = @search.result(distinct: true).includes(:automation_rule, :automation_action, :client, :incase).paginate(page: params[:page], per_page: 50)

    @stats = {
      total: current_account.automation_messages.count,
      sent: current_account.automation_messages.sent.count,
      failed: current_account.automation_messages.failed.count
    }
  end

  def check_status
    success, payload = @automation_message.check_delivery_status

    text =
      if payload.is_a?(Hash)
        # Собираем человекочитаемый текст на основе статуса/причины/времени
        if payload[:text].present?
          payload[:text]
        else
          parts = []
          parts << "статус: #{payload[:status]}" if payload[:status]
          parts << "причина: #{payload[:reason]}" if payload[:reason]
          if (ts = payload[:created_at])
            t = ts.is_a?(Time) ? ts : Time.zone ? Time.zone.at(ts.to_i) : Time.at(ts.to_i)
            parts << "время: #{t.strftime('%d.%m.%Y %H:%M')} (UTC+3)"
          end
          parts.any? ? "Статус доставки — " + parts.join(', ') : payload.inspect
        end
      else
        payload
      end

    respond_to do |format|
      format.turbo_stream do
        flash.now[success ? :success : :alert] = text
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.update(dom_id(current_account, dom_id(@automation_message)), partial: "automation_messages/automation_message", locals: { automation_message: @automation_message }),
        ]       
      end
      format.html do
        redirect_to account_automation_messages_path(current_account), flash: { (success ? :success : :alert) => text }
      end
    end
  end

  private

  def set_automation_message
    @automation_message = current_account.automation_messages.find(params[:id])
  end

end

