class AddDisplayNumberToIncases < ActiveRecord::Migration[8.0]
  def change
    add_column :incases, :display_number, :integer
    add_index :incases, [:account_id, :display_number], unique: true, where: "display_number IS NOT NULL"
  end
end
