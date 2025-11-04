class MigrateUsersToAccountUsers < ActiveRecord::Migration[8.0]
  def up
    # Перенос данных из users в account_users
    execute <<-SQL
      INSERT INTO account_users (user_id, account_id, role, created_at, updated_at)
      SELECT id, account_id, role, created_at, updated_at
      FROM users
      WHERE account_id IS NOT NULL
    SQL
  end

  def down
    # Откат: удалить все записи account_users
    execute "DELETE FROM account_users"
  end
end
