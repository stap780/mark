class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :plan, null: false, foreign_key: true, index: true
      t.string :status, null: false
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.boolean :cancel_at_period_end, default: false, null: false

      t.timestamps
    end
    
    add_index :subscriptions, :status
  end
end
