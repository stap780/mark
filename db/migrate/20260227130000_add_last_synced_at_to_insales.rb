# frozen_string_literal: true

class AddLastSyncedAtToInsales < ActiveRecord::Migration[7.1]
  def change
    add_column :insales, :last_synced_at, :datetime
  end
end
