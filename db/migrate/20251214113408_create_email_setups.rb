class CreateEmailSetups < ActiveRecord::Migration[8.0]
  def change
    create_table :email_setups do |t|
      t.string :address
      t.integer :port
      t.string :domain
      t.string :authentication
      t.string :user_name
      t.string :user_password
      t.boolean :tls, default: true
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :email_setups, :account_id, unique: true unless index_exists?(:email_setups, :account_id)
  end
end
