class AddLogicOperatorToAutomationRules < ActiveRecord::Migration[8.0]
  def change
    add_column :automation_rules, :logic_operator, :string, default: 'AND'
  end
end
