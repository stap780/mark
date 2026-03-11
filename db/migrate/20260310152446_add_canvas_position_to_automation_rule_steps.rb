class AddCanvasPositionToAutomationRuleSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :automation_rule_steps, :canvas_x, :integer
    add_column :automation_rule_steps, :canvas_y, :integer
  end
end
