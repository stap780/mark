class CreateAutomationMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :automation_messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :automation_rule, null: false, foreign_key: true
      t.references :automation_action, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.references :incase, null: true, foreign_key: true
      t.string :channel, null: false
      t.string :status, default: 'pending'
      t.text :subject
      t.text :content
      t.text :error_message
      t.datetime :sent_at
      t.datetime :delivered_at

      t.timestamps
    end

    add_index :automation_messages, [:account_id, :channel, :status]
    add_index :automation_messages, [:automation_rule_id, :created_at]
  end
end

