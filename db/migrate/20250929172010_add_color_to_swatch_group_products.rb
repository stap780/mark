class AddColorToSwatchGroupProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :swatch_group_products, :color, :string
  end
end
