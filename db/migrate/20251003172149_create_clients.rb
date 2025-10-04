class CreateClients < ActiveRecord::Migration[8.0]
  def change
    create_table :clients do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name
      t.string :surname
      t.string :email
      t.string :phone
      t.string :clientid
      t.string :ya_client

      t.timestamps
    end
    add_index :clients, :clientid, unique: true
  end
end
