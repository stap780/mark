class RemoveImageLinkFromProducts < ActiveRecord::Migration[7.2]
  def change
    if column_exists?(:products, :image_link)
      remove_column :products, :image_link, :string
    end
  end
end


