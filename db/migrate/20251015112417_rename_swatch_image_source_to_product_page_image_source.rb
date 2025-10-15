class RenameSwatchImageSourceToProductPageImageSource < ActiveRecord::Migration[8.0]
  def change
    rename_column :swatch_groups, :swatch_image_source, :product_page_image_source
  end
end
