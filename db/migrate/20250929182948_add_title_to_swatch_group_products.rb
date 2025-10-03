class AddTitleToSwatchGroupProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :swatch_group_products, :title, :string
  end
end
