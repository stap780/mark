class AddTriggerColumnsToWebforms < ActiveRecord::Migration[8.0]
  def change
    change_table :webforms, bulk: true do |t|
      t.string  :trigger_type
      t.integer :trigger_value
      t.integer :show_delay, default: 0, null: false
      t.boolean :show_once_per_session, default: true, null: false
      t.integer :show_frequency_days
      t.text    :target_pages
      t.text    :exclude_pages
      t.string  :target_devices
      t.string  :cookie_name
    end
  end
end


