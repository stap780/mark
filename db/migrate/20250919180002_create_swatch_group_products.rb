class CreateSwatchGroupProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :swatch_group_products do |t|
      t.references :swatch_group, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :swatch_value
      t.string :swatch_label
      t.string :custom_image_url
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :swatch_group_products, [:swatch_group_id, :product_id], unique: true, name: "index_sgp_on_group_and_product"
    add_index :swatch_group_products, :position
  end
end
