class DropPositionFromSwatchGroups < ActiveRecord::Migration[7.2]
  def change
    if column_exists?(:swatch_groups, :position)
      remove_column :swatch_groups, :position, :integer
    end
  end
end


