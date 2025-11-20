class AddNumberToIncases < ActiveRecord::Migration[8.0]
  def change
    add_column :incases, :number, :string
    add_index :incases, [:account_id, :number], unique: true, where: "number IS NOT NULL"
  end
end
