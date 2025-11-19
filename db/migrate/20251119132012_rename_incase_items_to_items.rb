class RenameIncaseItemsToItems < ActiveRecord::Migration[8.0]
  def up
    # Удаляем старые колонки и индексы
    remove_index :incase_items, name: "index_incase_items_on_incase_id_and_item_type_and_item_id" if index_exists?(:incase_items, [:incase_id, :item_type, :item_id])
    remove_column :incase_items, :item_type, :string if column_exists?(:incase_items, :item_type)
    remove_column :incase_items, :item_id, :bigint if column_exists?(:incase_items, :item_id)
    
    # Добавляем product_id и variant_id
    add_reference :incase_items, :product, null: false, foreign_key: true
    add_reference :incase_items, :variant, null: false, foreign_key: true
    
    # Переименовываем таблицу
    rename_table :incase_items, :items
  end

  def down
    # Удаляем колонки
    remove_reference :items, :product, foreign_key: true if column_exists?(:items, :product_id)
    remove_reference :items, :variant, foreign_key: true if column_exists?(:items, :variant_id)
    
    # Переименовываем обратно
    rename_table :items, :incase_items
    
    # Восстанавливаем старую структуру
    add_column :incase_items, :item_type, :string, null: false
    add_column :incase_items, :item_id, :bigint, null: false
    add_index :incase_items, [:incase_id, :item_type, :item_id]
  end
end
