class ChangeDefaultStatusOnWebforms < ActiveRecord::Migration[8.0]
  def up
    change_column_default :webforms, :status, from: "active", to: "inactive"
  end

  def down
    change_column_default :webforms, :status, from: "inactive", to: "active"
  end
end


