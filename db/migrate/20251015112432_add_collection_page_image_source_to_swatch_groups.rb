class AddCollectionPageImageSourceToSwatchGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :swatch_groups, :collection_page_image_source, :string, default: "first_product_image"
  end
end
