class AddAutomationRuleStepIdToAutomationConditions < ActiveRecord::Migration[8.0]
  def up
    add_reference :automation_conditions, :automation_rule_step, null: true, foreign_key: true
    change_column_null :automation_conditions, :automation_rule_id, true
    # Перенос: условия, привязанные к шагу через automation_rule_steps.automation_condition_id
    execute <<-SQL.squish
      UPDATE automation_conditions ac
      SET automation_rule_step_id = s.id
      FROM automation_rule_steps s
      WHERE s.automation_condition_id = ac.id
    SQL
  end

  def down
    remove_reference :automation_conditions, :automation_rule_step, foreign_key: true
    change_column_null :automation_conditions, :automation_rule_id, false
  end
end
