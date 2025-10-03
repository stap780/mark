class AllowNullProductIdOnSwatchGroupProducts < ActiveRecord::Migration[8.0]
  def change
    change_column_null :swatch_group_products, :product_id, true
  end
end


