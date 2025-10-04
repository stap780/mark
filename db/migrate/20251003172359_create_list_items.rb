class CreateListItems < ActiveRecord::Migration[8.0]
  def change
    create_table :list_items do |t|
      t.references :list, null: false, foreign_key: true
      t.references :item, polymorphic: true, null: false
      t.jsonb :metadata

      t.timestamps
    end
  end
end
