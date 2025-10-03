class AddImageLinkToSwatchGroupProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :swatch_group_products, :image_link, :string
  end
end
