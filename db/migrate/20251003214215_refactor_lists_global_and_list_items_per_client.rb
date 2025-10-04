class RefactorListsGlobalAndListItemsPerClient < ActiveRecord::Migration[8.0]
  def change
    # Lists: remove owner polymorphic columns
    if column_exists?(:lists, :owner_type)
      remove_column :lists, :owner_type, :string
    end
    if column_exists?(:lists, :owner_id)
      remove_column :lists, :owner_id, :bigint
    end

    # Ensure unique list name per account
    add_index :lists, [:account_id, :name], unique: true, name: "index_lists_on_account_and_name"

    # ListItems: add client reference
    add_reference :list_items, :client, null: false, foreign_key: true

    # Update unique index for list items to include client_id
    remove_index :list_items, name: "index_list_items_on_list_and_item" if index_exists?(:list_items, [:list_id, :item_type, :item_id], name: "index_list_items_on_list_and_item")
    add_index :list_items, [:list_id, :client_id, :item_type, :item_id], unique: true, name: "index_list_items_on_list_client_and_item"
  end
end

class RefactorListsGlobalAndListItemsPerClient < ActiveRecord::Migration[8.0]
  def change
  end
end
