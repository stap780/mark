class AddProductXmlToInsales < ActiveRecord::Migration[7.2]
  def change
    add_column :insales, :product_xml, :string
  end
end


