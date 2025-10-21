class CreateDiscounts < ActiveRecord::Migration[8.0]
  def change
    create_table :discounts do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title
      t.string :rule
      t.string :move
      t.string :shift
      t.string :points
      t.string :notice
      t.integer :position, default: 1, null: false

      t.timestamps
    end
  end
end
