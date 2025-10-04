class RemoveOwnerFromLists < ActiveRecord::Migration[8.0]
  def change
    remove_column :lists, :owner_type, :string
    remove_column :lists, :owner_id, :bigint
  end
end

class RemoveOwnerFromLists < ActiveRecord::Migration[8.0]
  def change
    remove_column :lists, :owner_type, :string
    remove_column :lists, :owner_id, :bigint
  end
end
