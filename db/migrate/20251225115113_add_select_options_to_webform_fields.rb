class AddSelectOptionsToWebformFields < ActiveRecord::Migration[8.0]
  def change
    add_column :webform_fields, :select_options, :text
  end
end
