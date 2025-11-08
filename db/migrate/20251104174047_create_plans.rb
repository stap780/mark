class CreatePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :plans do |t|
      t.string :name, null: false
      t.integer :price, null: false
      t.string :interval, null: false
      t.boolean :active, default: true, null: false
      t.integer :trial_days, default: 0, null: false

      t.timestamps
    end
    
    add_index :plans, :name, unique: true
    add_index :plans, :active
  end
end
