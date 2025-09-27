class CreateSwatchSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :swatch_settings do |t|
      t.string :setting_key, null: false
      t.text :setting_value
      t.string :setting_type, default: "string"

      t.timestamps
    end

    add_index :swatch_settings, :setting_key, unique: true
  end
end
