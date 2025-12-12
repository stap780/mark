class AutomationMessagesController < ApplicationController
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
end

