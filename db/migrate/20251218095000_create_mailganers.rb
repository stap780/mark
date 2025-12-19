class CreateMailganers < ActiveRecord::Migration[8.0]
  def change
    create_table :mailganers do |t|
      t.references :account, null: false, foreign_key: true
      t.string :api_key, null: false
      t.string :smtp_login, null: false
      t.string :api_key_web_portal, null: false

      t.timestamps
    end

    add_index :mailganers, :account_id, unique: true, if_not_exists: true
  end
end


