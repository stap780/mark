class AddAccountRefAndRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :account, null: false, foreign_key: true
    add_column :users, :role, :string, null: false, default: "member"
  end
end
