class AutomationConditionsController < ApplicationController
  include ActionView::RecordIdentifier
  include OffcanvasResponder

  before_action :set_automation_rule
  before_action :set_automation_rule_step
  before_action :set_automation_condition, only: [:edit, :update, :destroy]

  def index
    @automation_conditions = @step.automation_conditions.ordered
    render layout: false if turbo_frame_request?
  end

  def new
    @automation_condition = @step.automation_conditions.build
    @automation_condition.assign_attributes(
      field: params[:field].presence || AutomationRulesHelper::FIELD_MAPPING.keys.first || "incase.status",
      operator: params[:operator].presence || "equals",
      value: params[:value].presence || "new"
    )
  end

  def edit; end

  def create
    attrs = params[:automation_condition].present? ? automation_condition_params.to_h : default_condition_attributes
    @automation_condition = @step.automation_conditions.build(attrs)

    if @automation_condition.save
      flash.now[:success] = t('.success')
      streams = [
        render_turbo_flash,
        turbo_stream.append(dom_id(@step, :condition_content), partial: "automation_conditions/condition_row", locals: { step: @step, automation_rule: @automation_rule, automation_condition: @automation_condition, current_account: current_account }),
        turbo_stream.replace(step_card_frame_id, partial: "automation_rule_steps/step", locals: { step: @step, automation_rule: @automation_rule, current_account: current_account })
      ]
      streams.insert(1, turbo_stream.remove(dom_id(@step, :conditions_empty))) if @step.automation_conditions.count == 1
      respond_to do |format|
        format.turbo_stream { render turbo_stream: streams }
        format.html { redirect_to account_automation_rule_automation_rule_step_automation_conditions_path(current_account, @automation_rule, @step), notice: t(".success") }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = @automation_condition.errors.full_messages.join(", ")
          render turbo_stream: render_turbo_flash, status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @automation_condition.update(automation_condition_params)
      flash.now[:success] = t('.success')
      respond_to do |format|
        format.turbo_stream do
          streams = [
            render_turbo_flash,
            turbo_stream.replace(
              dom_id(@step, dom_id(@automation_condition)),
              params[:commit].present? ? render_to_string(partial: "automation_conditions/condition_row", locals: { step: @step, automation_rule: @automation_rule, automation_condition: @automation_condition, current_account: current_account }) : render_to_string(template: "automation_conditions/edit", layout: false)
            ),
            turbo_stream.replace(step_card_frame_id, partial: "automation_rule_steps/step", locals: { step: @step, automation_rule: @automation_rule, current_account: current_account })
          ]
          render turbo_stream: streams
        end
        format.html { redirect_to account_automation_rule_automation_rule_step_automation_conditions_path(current_account, @automation_rule, @step), notice: t(".success") }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = @automation_condition.errors.full_messages.join(", ")
          render turbo_stream: render_turbo_flash, status: :unprocessable_entity
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @automation_condition.destroy
    flash.now[:success] = t('.success')
    streams = [
      turbo_stream.remove(dom_id(@step, dom_id(@automation_condition))),
      turbo_stream.replace(step_card_frame_id, partial: "automation_rule_steps/step", locals: { step: @step, automation_rule: @automation_rule, current_account: current_account }),
      render_turbo_flash
    ]
    if @step.automation_conditions.reload.empty?
      streams.insert(1, turbo_stream.replace(dom_id(@step, :condition_content), render_to_string(partial: "automation_rule_steps/conditions_empty", locals: { step: @step })))
    end
    respond_to do |format|
      format.turbo_stream { render turbo_stream: streams }
      format.html { redirect_to account_automation_rule_automation_rule_step_automation_conditions_path(current_account, @automation_rule, @step), notice: t(".success") }
    end
  end

  private

  def set_automation_rule
    @automation_rule = current_account.automation_rules.find(params[:automation_rule_id])
  end

  def set_automation_rule_step
    @step = @automation_rule.automation_rule_steps.find(params[:automation_rule_step_id])
  end

  def set_automation_condition
    @automation_condition = @step.automation_conditions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    @automation_condition = AutomationCondition.new(id: params[:id])
  end

  def automation_condition_params
    params.require(:automation_condition).permit(:field, :operator, :value, :position)
  end

  def default_condition_attributes
    {
      field: AutomationRulesHelper::FIELD_MAPPING.keys.first || "incase.status",
      operator: "equals",
      value: "new",
      position: @step.automation_conditions.count
    }
  end

  def step_card_frame_id
    dom_id(current_account, dom_id(@automation_rule, dom_id(@step)))
  end

end