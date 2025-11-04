class RemoveAccountIdAndRoleFromUsers < ActiveRecord::Migration[8.0]
  def up
    # Удаляем foreign key на account_id перед удалением колонки
    if foreign_key_exists?(:users, :accounts)
      remove_foreign_key :users, :accounts
    end
    
    # Удаляем индекс на account_id перед удалением колонки
    remove_index :users, :account_id if index_exists?(:users, :account_id)
    
    # Удаляем колонки
    remove_column :users, :account_id, :integer
    remove_column :users, :role, :string
  end

  def down
    # Восстановление колонок при откате
    add_column :users, :account_id, :integer, null: true
    add_column :users, :role, :string, default: "member", null: false
    
    # Восстанавливаем индекс и foreign key
    add_index :users, :account_id
    add_foreign_key :users, :accounts unless foreign_key_exists?(:users, :accounts)
    
    # Обновляем данные из account_users обратно в users (только первый аккаунт для каждого пользователя)
    execute <<-SQL
      UPDATE users 
      SET account_id = (SELECT account_id FROM account_users WHERE account_users.user_id = users.id LIMIT 1),
          role = (SELECT role FROM account_users WHERE account_users.user_id = users.id LIMIT 1)
      WHERE EXISTS (SELECT 1 FROM account_users WHERE account_users.user_id = users.id)
    SQL
    
    # Устанавливаем NOT NULL для account_id после заполнения данных
    change_column_null :users, :account_id, false
  end
end
