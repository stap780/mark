class DropSwatchSettings < ActiveRecord::Migration[8.0]
  def up
    drop_table :swatch_settings, if_exists: true
  end

  def down
    create_table :swatch_settings do |t|
      t.string :setting_key, null: false
      t.text :setting_value
      t.string :setting_type, default: "string"
      t.timestamps null: false
    end
    add_index :swatch_settings, :setting_key, unique: true
  end
end


