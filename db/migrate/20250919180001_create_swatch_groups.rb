class CreateSwatchGroups < ActiveRecord::Migration[7.2]
  def change
    create_table :swatch_groups do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :option_name, null: false
      t.integer :status, default: 0
  t.string :product_page_style, default: "circular"
  t.string :collection_page_style, default: "circular_small"
      t.string :swatch_image_source, default: "first_product_image"
      t.boolean :visible_on_store, default: true
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :swatch_groups, :name
    add_index :swatch_groups, :status
    add_index :swatch_groups, :position
  end
end
