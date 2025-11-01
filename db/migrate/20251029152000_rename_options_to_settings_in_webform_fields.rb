class RenameOptionsToSettingsInWebformFields < ActiveRecord::Migration[8.0]
  def change
    rename_column :webform_fields, :options, :settings
  end
end

