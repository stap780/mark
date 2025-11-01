class AddJsonbToSettingCreateWebforms < ActiveRecord::Migration[8.0]
  def change
    change_column :webforms, :settings, :jsonb
    change_column :webform_fields, :options, :jsonb
  end
end
