class AddCssClassesToSwatchGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :swatch_groups, :css_class_product, :string
    add_column :swatch_groups, :css_class_preview, :string
  end
end


