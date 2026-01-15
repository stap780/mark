class CreateMoizvonkis < ActiveRecord::Migration[8.0]
  def change
    create_table :moizvonkis do |t|
      t.references :account, null: false, foreign_key: true
      t.string :domain, null: false
      t.string :user_name, null: false
      t.string :api_key, null: false
      t.string :webhook_secret, null: false

      t.timestamps
    end

    add_index :moizvonkis, :account_id, unique: true, if_not_exists: true
  end
end

