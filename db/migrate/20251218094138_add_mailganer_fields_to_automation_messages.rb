class AddMailganerFieldsToAutomationMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :automation_messages, :message_id, :string
    add_column :automation_messages, :x_track_id, :string

    add_index :automation_messages, :message_id
    add_index :automation_messages, :x_track_id
  end
end


