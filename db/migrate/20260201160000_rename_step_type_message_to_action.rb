# frozen_string_literal: true

class RenameStepTypeMessageToAction < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL.squish
      UPDATE automation_rule_steps SET step_type = 'action' WHERE step_type = 'message';
    SQL
  end

  def down
    execute <<-SQL.squish
      UPDATE automation_rule_steps SET step_type = 'message' WHERE step_type = 'action';
    SQL
  end
end
