class AddCustomFieldsToIncases < ActiveRecord::Migration[8.0]
  def change
    add_column :incases, :custom_fields, :jsonb, default: {}
    add_index :incases, :custom_fields, using: :gin
  end
end
