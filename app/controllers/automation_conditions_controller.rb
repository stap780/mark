class AutomationConditionsController < ApplicationController
  include ActionView::RecordIdentifier
  include OffcanvasResponder

  before_action :set_automation_rule
  before_action :set_automation_condition, only: [:destroy]

  def new
    @automation_condition = @automation_rule.automation_conditions.build
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def create
    @automation_condition = @automation_rule.automation_conditions.build(automation_condition_params)

    respond_to do |format|
      if @automation_condition.save
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              dom_id(current_account, dom_id(@automation_rule, :automation_conditions)),
              partial: "automation_conditions/automation_condition",
              locals: { automation_rule: @automation_rule, automation_condition: @automation_condition, current_account: current_account }
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
    check_destroy = @automation_condition.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @automation_condition.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@automation_condition)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to edit_account_automation_rule_path(current_account, @automation_rule), notice: t(".success") }
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

  def set_automation_condition
    @automation_condition = @automation_rule.automation_conditions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    @automation_condition = AutomationCondition.new(id: params[:id])
  end

  def automation_condition_params
    params.require(:automation_condition).permit(:field, :operator, :value, :position)
  end
end

