class CreateAutomationRules < ActiveRecord::Migration[8.0]
  def change
    create_table :automation_rules do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title, null: false
      t.string :event, null: false
      t.string :condition_type, default: 'simple'
      t.text :condition
      t.boolean :active, default: true
      t.integer :position
      t.integer :delay_seconds, default: 0
      t.datetime :scheduled_for
      t.string :active_job_id

      t.timestamps
    end

    add_index :automation_rules, :scheduled_for
    add_index :automation_rules, :active_job_id
  end
end

