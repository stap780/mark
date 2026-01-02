class AddUserToAutomationMessages < ActiveRecord::Migration[8.0]
  def change
    add_reference :automation_messages, :user, null: true, foreign_key: true
    change_column_null :automation_messages, :client_id, true
  end
end
