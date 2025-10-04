class RemoveVariantIdFromVarbinds < ActiveRecord::Migration[8.0]
  def change
    # Remove the old variant_id column since we now use polymorphic record
    remove_column :varbinds, :variant_id, :bigint
    remove_foreign_key :varbinds, :variants if foreign_key_exists?(:varbinds, :variants)
  end
end
