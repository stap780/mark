class AddSettingsToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :settings, :jsonb, default: {}
  end
end
