class UpdateListItemsAddClientAndRemoveMetadata < ActiveRecord::Migration[8.0]
  def change
    add_reference :list_items, :client, null: false, foreign_key: true
    remove_column :list_items, :metadata, :jsonb
    add_index :list_items, [:list_id, :client_id, :item_type, :item_id], unique: true, name: "index_list_items_on_list_client_and_item"
  end
end


