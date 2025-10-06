class AddIconStyleToLists < ActiveRecord::Migration[7.1]
  def change
    add_column :lists, :icon_style, :string, null: false, default: "icon_one"
    add_column :lists, :icon_color, :string, null: false, default: "#999999"
    add_index :lists, :icon_style
  end
end


