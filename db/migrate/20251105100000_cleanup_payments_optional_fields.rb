class CleanupPaymentsOptionalFields < ActiveRecord::Migration[7.1]
  def change
    remove_column :payments, :processor_id, :string, if_exists: true
    remove_column :payments, :invoice_number, :string, if_exists: true
    remove_column :payments, :invoice_status, :string, if_exists: true
    remove_column :payments, :invoice_issued_at, :datetime, if_exists: true
  end
end


