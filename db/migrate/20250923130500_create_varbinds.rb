class CreateVarbinds < ActiveRecord::Migration[7.2]
  def change
    create_table :varbinds do |t|
      t.references :variant, null: false, foreign_key: true
      t.references :varbindable, polymorphic: true, null: false
      t.string :value, null: false
      t.timestamps
    end

    add_index :varbinds, :value
  end
end


