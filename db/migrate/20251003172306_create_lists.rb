class CreateLists < ActiveRecord::Migration[8.0]
  def change
    create_table :lists do |t|
      t.references :account, null: false, foreign_key: true
      t.references :owner, polymorphic: true, null: false
      t.string :name
      t.integer :items_count

      t.timestamps
    end
  end
end
