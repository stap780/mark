class CreateVariants < ActiveRecord::Migration[7.2]
  def change
    create_table :variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :barcode
      t.string :sku
      t.decimal :price, precision: 12, scale: 2
      t.string :image_link
      t.timestamps
    end

    add_index :variants, :barcode
    add_index :variants, :sku
  end
end


