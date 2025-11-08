class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :subscription, null: false, foreign_key: true, index: true
      t.integer :amount, null: false
      t.string :status, null: false
      t.datetime :paid_at
      t.string :processor, null: false
      t.string :processor_id
      t.string :invoice_number
      t.string :invoice_status
      t.datetime :invoice_issued_at
      t.jsonb :processor_data

      t.timestamps
    end
    
    add_index :payments, :status
    add_index :payments, :processor
    add_index :payments, :invoice_number, unique: true, where: "invoice_number IS NOT NULL"
  end
end
