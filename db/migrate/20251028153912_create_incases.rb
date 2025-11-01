class CreateIncases < ActiveRecord::Migration[8.0]
  def change
    create_table :incases, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true
      t.references :webform, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.string :status

      t.timestamps
    end
  end
end
