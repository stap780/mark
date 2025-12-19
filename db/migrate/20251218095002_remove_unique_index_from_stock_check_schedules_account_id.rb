class RemoveUniqueIndexFromStockCheckSchedulesAccountId < ActiveRecord::Migration[8.0]
  def change
    remove_index :stock_check_schedules, :account_id, if_exists: true
    add_index :stock_check_schedules, :account_id, if_not_exists: true
  end
end
