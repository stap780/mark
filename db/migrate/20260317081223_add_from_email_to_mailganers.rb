class AddFromEmailToMailganers < ActiveRecord::Migration[8.0]
  def change
    add_column :mailganers, :from_email, :string
  end
end
