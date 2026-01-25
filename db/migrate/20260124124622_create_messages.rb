class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.string :direction, null: false
      t.string :channel, null: false
      t.text :content
      t.text :subject
      t.string :status, default: 'sent'
      t.references :user, null: true, foreign_key: true
      t.string :message_id
      t.string :replied_to_message_id
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :read_at
      t.text :error_message

      t.timestamps
    end

    add_index :messages, [:conversation_id, :created_at]
    add_index :messages, [:account_id, :channel, :status]
    add_index :messages, :message_id
  end
end
