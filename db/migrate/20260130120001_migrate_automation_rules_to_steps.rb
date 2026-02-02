# frozen_string_literal: true

class MigrateAutomationRulesToSteps < ActiveRecord::Migration[8.0]
  def up
    return unless table_exists?(:automation_rule_steps)

    AutomationRule.find_each do |rule|
      next if rule.automation_rule_steps.exists?

      steps_to_link = []
      position = 1

      # Используем unscoped для обхода scope, который ссылается на несуществующую колонку automation_rule_step_id
      conditions = AutomationCondition.unscoped.where(automation_rule_id: rule.id).order(:position, :id)
      if conditions.any?
        cond = conditions.first
        step = rule.automation_rule_steps.create!(
          position: position,
          step_type: "condition",
          automation_condition_id: cond.id
        )
        steps_to_link << step
        position += 1
      end

      if rule.delay_seconds.to_i.positive?
        step = rule.automation_rule_steps.create!(
          position: position,
          step_type: "pause",
          delay_seconds: rule.delay_seconds
        )
        steps_to_link << step
        position += 1
      end

      rule.automation_actions.order(:position).each do |action|
        step = rule.automation_rule_steps.create!(
          position: position,
          step_type: "action",
          automation_action_id: action.id
        )
        steps_to_link << step
        position += 1
      end

      steps_to_link.each_cons(2) do |prev_step, next_step|
        prev_step.update_column(:next_step_id, next_step.id)
      end
    end
  end

  def down
    return unless table_exists?(:automation_rule_steps)

    AutomationRuleStep.delete_all
  end
end
