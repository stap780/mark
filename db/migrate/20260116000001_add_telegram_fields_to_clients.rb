class AddTelegramFieldsToClients < ActiveRecord::Migration[8.0]
  def change
    add_column :clients, :telegram_chat_id, :string
    add_column :clients, :telegram_username, :string
  end
end
