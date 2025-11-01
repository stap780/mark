class CreateWebformFields < ActiveRecord::Migration[8.0]
  def change
    create_table :webform_fields, if_not_exists: true do |t|
      t.references :webform, null: false, foreign_key: true
      t.string :name, null: false
      t.string :label, null: false
      t.string :field_type, null: false
      t.boolean :required, default: false, null: false
      t.json :options
      t.integer :position
      t.timestamps
    end

    add_index :webform_fields, [:webform_id, :name], unique: true, if_not_exists: true
  end
end
