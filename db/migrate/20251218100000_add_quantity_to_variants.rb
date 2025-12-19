class AddQuantityToVariants < ActiveRecord::Migration[7.1]
  def change
    add_column :variants, :quantity, :integer, null: false, default: 0
  end
end


