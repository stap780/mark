class CreateWebforms < ActiveRecord::Migration[8.0]
  def change
    create_table :webforms, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title, null: false
      t.string :kind, null: false
      t.string :status, null: false, default: 'active'
      t.json :settings
      t.timestamps
    end

    add_index :webforms, [:account_id, :kind, :status], if_not_exists: true
    add_index :webforms, [:account_id, :kind], unique: true,
      where: "kind IN ('order','notify','preorder','abandoned_cart')",
      name: 'index_webforms_on_account_kind_singleton', if_not_exists: true
  end
end
