class RemoveClientidFromClients < ActiveRecord::Migration[8.0]
  def change
    # Remove clientid column since we now use varbinds for external ID mapping
    remove_column :clients, :clientid, :string
    remove_index :clients, :clientid if index_exists?(:clients, :clientid)
  end
end
