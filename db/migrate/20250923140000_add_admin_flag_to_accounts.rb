class AddAdminFlagToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :accounts, :admin, :boolean, default: false, null: false
    add_index :accounts, :admin
  end
end


