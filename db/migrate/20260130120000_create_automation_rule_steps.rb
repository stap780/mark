# frozen_string_literal: true

class CreateAutomationRuleSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :automation_rule_steps do |t|
      t.references :automation_rule, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :step_type, null: false
      t.references :automation_condition, null: true, foreign_key: true
      t.references :automation_action, null: true, foreign_key: true
      t.references :message_template, null: true, foreign_key: true
      t.integer :delay_seconds, null: true
      t.references :next_step, null: true, foreign_key: { to_table: :automation_rule_steps }
      t.references :next_step_when_false, null: true, foreign_key: { to_table: :automation_rule_steps }

      t.timestamps
    end

    add_index :automation_rule_steps, [:automation_rule_id, :position]
  end
end
