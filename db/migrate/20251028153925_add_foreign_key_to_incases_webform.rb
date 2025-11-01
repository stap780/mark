class AddForeignKeyToIncasesWebform < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :incases, :webforms, if_not_exists: true
  end
end
