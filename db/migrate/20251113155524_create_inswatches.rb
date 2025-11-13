class CreateInswatches < ActiveRecord::Migration[8.0]
  def change
    create_table :inswatches do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :uid, null: false
      t.string :shop
      t.boolean :installed, default: false, null: false
      t.datetime :last_login_at

      t.timestamps
    end

    add_index :inswatches, :uid, unique: true
    add_index :inswatches, :shop
  end
end
