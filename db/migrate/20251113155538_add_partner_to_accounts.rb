class AddPartnerToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :partner, :boolean, default: false, null: false
    add_index :accounts, :partner
  end
end
