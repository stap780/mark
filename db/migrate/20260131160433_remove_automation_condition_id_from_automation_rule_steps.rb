class RemoveAutomationConditionIdFromAutomationRuleSteps < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :automation_rule_steps, :automation_conditions, if_exists: true
    remove_column :automation_rule_steps, :automation_condition_id, :bigint
  end
end
