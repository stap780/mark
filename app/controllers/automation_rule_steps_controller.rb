# frozen_string_literal: true

class AutomationRuleStepsController < ApplicationController
  include ActionView::RecordIdentifier
  include OffcanvasResponder

  before_action :set_automation_rule
  before_action :set_step, only: [:show, :edit, :update, :destroy]

  def show
    render layout: false if turbo_frame_request?
  end

  def edit
  end

  def create
    if params[:step_type] == "action" && @automation_rule.account.message_templates.email.none?
      flash.now[:alert] = t("automation_rule_steps.no_template", default: "Создайте шаблон сообщения (email) для добавления блока «Действие».")
      return respond_to do |format|
        format.turbo_stream { render turbo_stream: render_turbo_flash, status: :unprocessable_entity }
        format.html { redirect_to chain_account_automation_rule_path(current_account, @automation_rule), alert: flash[:alert] }
      end
    end
    position = compute_position
    @step = build_step(position)

    if @step.save
      link_previous_step_to_new_one
      flash.now[:success] = t("automation_rule_steps.created")
      steps_frame_id = dom_id(current_account, dom_id(@automation_rule, :steps))
      tree_content = render_to_string(
        partial: "automation_rules/steps_tree",
        locals: { automation_rule: @automation_rule, current_account: current_account }
      )
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update(steps_frame_id, tree_content),
            turbo_stream.update(:offcanvas, ""),
            render_turbo_flash
          ]
        end
        format.html { redirect_to chain_account_automation_rule_path(current_account, @automation_rule) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: render_turbo_flash, status: :unprocessable_entity
        end
        format.html { redirect_to chain_account_automation_rule_path(current_account, @automation_rule), alert: @step.errors.full_messages.join(", ") }
      end
    end
  end

  def update
    permitted = step_params.to_h
    action_attrs = permitted.delete("automation_action_attributes")
    if @step.update(permitted)
      update_step_action(action_attrs)
      respond_to do |format|
        format.turbo_stream do
          offcanvas_stream = if @step.action? && params[:commit].blank?
            turbo_stream.replace(
              dom_id(current_account, dom_id(@step, :step_form)),
              render_to_string(partial: "automation_rule_steps/action_form_frame", locals: { step: @step, automation_rule: @automation_rule, current_account: current_account })
            )
          else
            turbo_stream.update(:offcanvas, "")
          end
          render turbo_stream: [
            turbo_stream.replace(dom_id(current_account, dom_id(@automation_rule, dom_id(@step))), partial: "automation_rule_steps/step", locals: { step: @step, automation_rule: @automation_rule, current_account: current_account }),
            offcanvas_stream,
            render_turbo_flash
          ]
        end
        format.html { redirect_to chain_account_automation_rule_path(current_account, @automation_rule) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: render_turbo_flash, status: :unprocessable_entity }
        format.html { redirect_to chain_account_automation_rule_path(current_account, @automation_rule), alert: @step.errors.full_messages.join(", ") }
      end
    end
  end

  def destroy
    nullify_references_to_step
    @step.destroy
    steps_frame_id = dom_id(current_account, dom_id(@automation_rule, :steps))
    tree_content = render_to_string(
      partial: "automation_rules/steps_tree",
      locals: { automation_rule: @automation_rule, current_account: current_account }
    )
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(steps_frame_id, tree_content),
          render_turbo_flash
        ]
      end
      format.html { redirect_to chain_account_automation_rule_path(current_account, @automation_rule) }
    end
  end

  private

  def set_automation_rule
    @automation_rule = current_account.automation_rules.find(params[:automation_rule_id])
  end

  def set_step
    @step = @automation_rule.automation_rule_steps.find(params[:id])
  end

  def step_params
    params.require(:automation_rule_step).permit(
      :step_type, :position, :delay_seconds, :next_step_id, :next_step_when_false_id,
      automation_action_attributes: [:id, :kind, :value]
    )
  end

  def update_step_action(action_attrs)
    return if action_attrs.blank? || @step.automation_action.blank?

    attrs = action_attrs.is_a?(ActionController::Parameters) ? action_attrs.permit(:kind, :value).to_h : action_attrs.slice("kind", "value")
    @step.automation_action.update(attrs)
  end

  def compute_position
    insert_after = params[:insert_after_step_id].presence
    if insert_after.present?
      prev = @automation_rule.automation_rule_steps.find_by(id: insert_after)
      prev ? prev.position + 1 : (@automation_rule.automation_rule_steps.maximum(:position) || 0) + 1
    else
      (params[:position].presence || @automation_rule.automation_rule_steps.maximum(:position).to_i + 1).to_i
    end
  end

  def build_step(position)
    step_type = params[:step_type].presence || "pause"
    step = @automation_rule.automation_rule_steps.build(step_type: step_type, position: position)

    case step_type
    when "condition"
      # Условия добавляются отдельно через show → «+ Добавить условие»
    when "pause"
      step.delay_seconds = params[:delay_seconds].presence&.to_i || 3600
    when "action"
      template = @automation_rule.account.message_templates.email.first
      action = @automation_rule.automation_actions.build(
        kind: "send_email",
        value: template&.id&.to_s || "",
        position: @automation_rule.automation_actions.maximum(:position).to_i + 1
      )
      action.save! if template
      step.automation_action_id = action.id if action.persisted?
    end

    step
  end

  def nullify_references_to_step
    @automation_rule.automation_rule_steps.where(next_step_id: @step.id).update_all(next_step_id: nil)
    @automation_rule.automation_rule_steps.where(next_step_when_false_id: @step.id).update_all(next_step_when_false_id: nil)
  end

  def link_previous_step_to_new_one
    insert_after_id = params[:insert_after_step_id].presence
    return if insert_after_id.blank?

    prev_step = @automation_rule.automation_rule_steps.find_by(id: insert_after_id)
    return if prev_step.blank?

    branch = params[:branch]
    if prev_step.condition? && branch.present?
      if branch == "true"
        # Сохраняем ссылку на следующий шаг, который был после предыдущего
        old_next_step_id = prev_step.next_step_id
        prev_step.update_column(:next_step_id, @step.id)
        # Устанавливаем ссылку нового шага на сохраненный следующий шаг
        @step.update_column(:next_step_id, old_next_step_id) if old_next_step_id.present?
      else
        # Сохраняем ссылку на следующий шаг (ветка "Нет")
        old_next_step_when_false_id = prev_step.next_step_when_false_id
        prev_step.update_column(:next_step_when_false_id, @step.id)
        # Устанавливаем ссылку нового шага на сохраненный следующий шаг
        @step.update_column(:next_step_id, old_next_step_when_false_id) if old_next_step_when_false_id.present?
      end
    else
      # Сохраняем ссылку на следующий шаг, который был после предыдущего
      old_next_step_id = prev_step.next_step_id
      prev_step.update_column(:next_step_id, @step.id)
      # Устанавливаем ссылку нового шага на сохраненный следующий шаг
      @step.update_column(:next_step_id, old_next_step_id) if old_next_step_id.present?
    end
  end

end
