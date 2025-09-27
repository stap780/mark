class DropVisibleOnStoreFromSwatchGroups < ActiveRecord::Migration[7.2]
  def change
    if column_exists?(:swatch_groups, :visible_on_store)
      remove_column :swatch_groups, :visible_on_store, :boolean
    end
  end
end


