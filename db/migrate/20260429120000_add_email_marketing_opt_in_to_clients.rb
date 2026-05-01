# frozen_string_literal: true

class AddEmailMarketingOptInToClients < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:clients, :email_marketing_opt_in)
      add_column :clients, :email_marketing_opt_in, :boolean, default: false, null: false
    end
    unless column_exists?(:clients, :email_marketing_opt_in_at)
      add_column :clients, :email_marketing_opt_in_at, :datetime
    end
  end
end
