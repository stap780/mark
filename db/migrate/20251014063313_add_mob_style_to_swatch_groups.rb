class AddMobStyleToSwatchGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :swatch_groups, :product_page_style_mob, :string
    add_column :swatch_groups, :collection_page_style_mob, :string
  end
end
