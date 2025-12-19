class CreateStockCheckSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :stock_check_schedules do |t|
      t.references :account, null: false, foreign_key: true
      t.boolean :active, default: false
      t.string :time
      t.string :recurrence
      t.datetime :scheduled_for
      t.string :active_job_id

      t.timestamps
    end

    add_index :stock_check_schedules, :account_id, unique: true, if_not_exists: true
  end
end
