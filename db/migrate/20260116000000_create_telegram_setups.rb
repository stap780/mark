class CreateTelegramSetups < ActiveRecord::Migration[8.0]
  def change
    create_table :telegram_setups do |t|
      t.references :account, null: false, foreign_key: true
      t.string :bot_token
      t.string :personal_phone
      t.text :personal_session
      t.boolean :personal_authorized, default: false, null: false
      t.string :webhook_secret

      t.timestamps
    end

    add_index :telegram_setups, :account_id, unique: true, if_not_exists: true
  end
end
