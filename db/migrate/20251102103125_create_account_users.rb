class CreateAccountUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :account_users do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :role, null: false, default: "member"

      t.timestamps
    end

    add_index :account_users, [:user_id, :account_id], unique: true
    add_index :account_users, :role
  end
end
