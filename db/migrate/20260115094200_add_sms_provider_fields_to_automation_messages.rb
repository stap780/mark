class AddSmsProviderFieldsToAutomationMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :automation_messages, :provider, :string
    add_column :automation_messages, :provider_payload, :jsonb

    add_index :automation_messages, :provider
  end
end

