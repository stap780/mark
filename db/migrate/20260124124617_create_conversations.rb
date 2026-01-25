class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.references :incase, null: true, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :status, default: 'active'
      t.datetime :last_message_at
      t.datetime :last_outgoing_at
      t.datetime :last_incoming_at

      t.timestamps
    end

    add_index :conversations, [:account_id, :client_id]
    add_index :conversations, [:account_id, :status]
  end
end
