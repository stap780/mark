class AddSwatchTextToSwatchGroupProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :swatch_group_products, :swatch_label, :string
  end
end
