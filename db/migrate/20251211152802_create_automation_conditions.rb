class CreateAutomationConditions < ActiveRecord::Migration[8.0]
  def change
    create_table :automation_conditions do |t|
      t.references :automation_rule, null: false, foreign_key: true
      t.string :field, null: false
      t.string :operator, null: false
      t.string :value
      t.integer :position

      t.timestamps
    end

    add_index :automation_conditions, [:automation_rule_id, :position]
  end
end
