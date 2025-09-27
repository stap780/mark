class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title
      t.string :image_link

      t.timestamps
    end
  end
end
