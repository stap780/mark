class CreateAutomationActions < ActiveRecord::Migration[8.0]
  def change
    create_table :automation_actions do |t|
      t.references :automation_rule, null: false, foreign_key: true
      t.string :kind, null: false
      t.jsonb :settings
      t.integer :position

      t.timestamps
    end
  end
end

