class List < ApplicationRecord
  include ActionView::RecordIdentifier
  belongs_to :account
  has_many :list_items, dependent: :destroy

  # Hotwire broadcasts
  after_create_commit do
    broadcast_prepend_to [account, :lists],
                        target: [account, :lists],
                        partial: "lists/list",
                        locals: { list: self }
  end

  after_update_commit do
    broadcast_replace_to [account, :lists],
                        target: dom_id(self),
                        partial: "lists/list",
                        locals: { list: self }
  end

  after_destroy_commit do
    broadcast_remove_to [account, :lists], target: dom_id(self)
  end
end
