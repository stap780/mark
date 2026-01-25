class AddTelegramBlockToClients < ActiveRecord::Migration[8.0]
  def change
    add_column :clients, :telegram_block, :boolean, default: false, null: false
  end
end
