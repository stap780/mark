class CreateIdgtls < ActiveRecord::Migration[8.0]
  def change
    create_table :idgtls do |t|
      t.references :account, null: false, foreign_key: true
      t.string :token_1, null: false
      t.string :sender_name, null: false

      t.timestamps
    end

    add_index :idgtls, :account_id, unique: true, if_not_exists: true
  end
end

