# frozen_string_literal: true

class CreateProductXmlOffers < ActiveRecord::Migration[7.1]
  def change
    create_table :product_xml_offers do |t|
      t.references :insale, null: false, foreign_key: true
      t.string :offer_id, null: false
      t.string :group_id
      t.string :model
      t.string :vendor_code
      t.string :picture
      t.jsonb :pictures, default: []
      t.string :url
      t.decimal :price, precision: 12, scale: 2

      t.timestamps
    end

    add_index :product_xml_offers, [:insale_id, :model]
    add_index :product_xml_offers, [:insale_id, :vendor_code]
    add_index :product_xml_offers, [:insale_id, :offer_id]
  end
end
