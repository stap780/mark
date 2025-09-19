class CreateInsales < ActiveRecord::Migration[8.0]
  def change
    create_table :insales do |t|
      t.string :api_key
      t.string :api_password
      t.string :api_link
      t.references :account, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
