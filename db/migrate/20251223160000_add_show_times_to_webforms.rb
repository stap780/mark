class AddShowTimesToWebforms < ActiveRecord::Migration[8.0]
  def change
    add_column :webforms, :show_times, :integer
  end
end


