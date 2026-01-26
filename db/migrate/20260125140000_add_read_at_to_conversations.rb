# frozen_string_literal: true

class AddReadAtToConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :conversations, :read_at, :datetime
  end
end
