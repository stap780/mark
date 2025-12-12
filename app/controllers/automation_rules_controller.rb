class AutomationRulesController < ApplicationController
  include OffcanvasResponder
  include ActionView::RecordIdentifier

  before_action :set_automation_rule, only: [:edit, :update, :destroy, :design, :build]

  def index
    @automation_rules = current_account.automation_rules.order(:position, :created_at)
  end

  def new
    @automation_rule = current_account.automation_rules.build
  end

  def create
    @automation_rule = current_account.automation_rules.build(automation_rule_params)
    @automation_rule.condition_type ||= 'simple' # Установить по умолчанию

    respond_to do |format|
      if @automation_rule.save
        flash[:success] = "Правило создано"
        format.turbo_stream { redirect_to edit_account_automation_rule_path(current_account, @automation_rule, format: :html) }
        format.html { redirect_to edit_account_automation_rule_path(current_account, @automation_rule) }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update

    respond_to do |format|
      if @automation_rule.update(automation_rule_params)
        flash.now[:success] = "Правило обновлено"
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(current_account, dom_id(@automation_rule)),
              partial: "automation_rules/automation_rule",
              locals: { automation_rule: @automation_rule, current_account: current_account }
            )
          ]
        end
        format.html { redirect_to account_automation_rules_path(current_account) }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @automation_rule.destroy
    respond_to do |format|
      flash.now[:success] = t('.success')
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove( dom_id(@automation_rule, dom_id(current_account))),
          render_turbo_flash
        ]
      end
      format.html { redirect_to account_automation_rules_path(current_account), notice: t('.success') }
    end
  end

  # Визуальный конструктор условий (как design в webform_fields_controller)
  def design
    # Открывается в offcanvas с визуальным конструктором
  end

  # Сохранение условий из визуального конструктора (как build в webform_fields_controller)
  def build
    respond_to do |format|
      if @automation_rule.update(automation_rule_params)
        # Обновляем preview условий через Turbo Streams
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update(
              dom_id(current_account, dom_id(@automation_rule, :condition_preview)),
              partial: "automation_rules/condition_preview",
              locals: { automation_rule: @automation_rule }
            ),
            turbo_stream.update(
              dom_id(@automation_rule, :condition_builder),
              partial: "automation_rules/condition_builder",
              locals: { automation_rule: @automation_rule, form: nil }
            )
          ]
        end
        format.html { head :ok }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            :offcanvas,
            partial: "automation_rules/design"
          ), status: :unprocessable_entity
        end
        format.html { render :design, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_automation_rule
    @automation_rule = current_account.automation_rules.find(params[:id])
  end

  def automation_rule_params
    params.require(:automation_rule).permit(
      :title, :event, :condition_type, :condition, :active, :delay_seconds, :position, :logic_operator,
      automation_conditions_attributes: [:id, :field, :operator, :value, :position, :_destroy],
      automation_actions_attributes: [:id, :kind, :position, :_destroy,
        :template_id, :new_status]
    )
  end

end

