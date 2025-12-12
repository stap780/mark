class AutomationActionsController < ApplicationController
  include OffcanvasResponder
  include ActionView::RecordIdentifier

  before_action :set_automation_rule
  before_action :set_automation_action, only: [:destroy]

  def new
    @automation_action = @automation_rule.automation_actions.build
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def create
    @automation_action = @automation_rule.automation_actions.build(automation_action_params)

    respond_to do |format|
      if @automation_action.save
        flash.now[:success] = "Действие добавлено"
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              dom_id(current_account, dom_id(@automation_rule, :automation_actions)),
              partial: "automation_actions/automation_action",
              locals: { automation_rule: @automation_rule, automation_action: @automation_action, current_account: current_account }
            )
          ]
        end
        format.html { redirect_to edit_account_automation_rule_path(current_account, @automation_rule) }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @automation_action.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @automation_action.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@automation_action)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to edit_account_automation_rule_path(current_account, @automation_rule) }
    end
  end

  private

  def set_automation_rule
    if params[:automation_rule_id].present?
      @automation_rule = current_account.automation_rules.find(params[:automation_rule_id])
    else
      # Для новых записей создаем временный объект
      @automation_rule = current_account.automation_rules.new
    end
  end

  def set_automation_action
    @automation_action = @automation_rule.automation_actions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    @automation_action = AutomationAction.new(id: params[:id])
  end

  def automation_action_params
    permitted = params.require(:automation_action).permit(:kind, :position, :template_id, :status)

    # Преобразуем template_id и status в settings JSONB
    settings = {}
    if permitted[:template_id].present? && permitted[:kind] == 'send_email'
      settings['template_id'] = permitted[:template_id].to_i
    end
    if permitted[:status].present? && permitted[:kind] == 'change_status'
      settings['status'] = permitted[:status]
    end

    permitted[:settings] = settings
    permitted.delete(:template_id)
    permitted.delete(:status)

    permitted
  end
end

