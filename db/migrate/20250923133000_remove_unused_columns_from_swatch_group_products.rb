class RemoveUnusedColumnsFromSwatchGroupProducts < ActiveRecord::Migration[7.2]
  def change
    if column_exists?(:swatch_group_products, :swatch_label)
      remove_column :swatch_group_products, :swatch_label, :string
    end

    if column_exists?(:swatch_group_products, :custom_image_url)
      remove_column :swatch_group_products, :custom_image_url, :string
    end

    if column_exists?(:swatch_group_products, :position)
      remove_column :swatch_group_products, :position, :integer
    end

    if index_exists?(:swatch_group_products, :position)
      remove_index :swatch_group_products, :position
    end
  end
end


