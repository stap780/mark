class CreateIncaseItems < ActiveRecord::Migration[8.0]
  def change
    create_table :incase_items, if_not_exists: true do |t|
      t.references :incase, null: false, foreign_key: true
      t.string :item_type, null: false
      t.bigint :item_id, null: false
      t.integer :quantity
      t.decimal :price, precision: 12, scale: 2
      t.timestamps
    end

    add_index :incase_items, [:incase_id, :item_type, :item_id], if_not_exists: true
  end
end
