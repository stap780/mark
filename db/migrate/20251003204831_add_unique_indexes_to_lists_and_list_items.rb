class AddUniqueIndexesToListsAndListItems < ActiveRecord::Migration[8.0]
  def change
    # Ensure unique list names per owner within an account
    add_index :lists, [:account_id, :owner_type, :owner_id, :name], unique: true, name: "index_lists_on_account_owner_and_name"

    # Ensure unique items per list
    add_index :list_items, [:list_id, :item_type, :item_id], unique: true, name: "index_list_items_on_list_and_item"
  end
end

class AddUniqueIndexesToListsAndListItems < ActiveRecord::Migration[8.0]
  def change
  end
end
