class CreateInsaleStatusMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :insale_status_mappings do |t|
      t.references :insale, null: false, foreign_key: true
      t.string :insales_custom_status_permalink, null: false
      t.string :insales_financial_status, null: false
      t.references :incase_status, null: false, foreign_key: true

      t.timestamps
    end

    add_index :insale_status_mappings,
              %i[insale_id insales_custom_status_permalink insales_financial_status],
              unique: true,
              name: "index_insale_status_mappings_unique"
  end
end
