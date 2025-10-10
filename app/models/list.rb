class List < ApplicationRecord
  include ActionView::RecordIdentifier
  include AccountScoped
  belongs_to :account
  has_many :list_items, dependent: :destroy

  ICON_STYLES = {
    "icon_one" => "Heart",
    "icon_two" => "Wishlist",
    "icon_three" => "Like"
  }.freeze

  validates :icon_style, inclusion: { in: ICON_STYLES.keys }

  # Hotwire broadcasts
  after_create_commit do
    broadcast_prepend_to [account, :lists],
                        target: [account, :lists],
                        partial: "lists/list",
                        locals: { list: self, current_account: account }
  end

  after_update_commit do
    broadcast_replace_to [account, :lists],
                        target: dom_id(self),
                        partial: "lists/list",
                        locals: { list: self, current_account: account }
  end

  after_destroy_commit do
    broadcast_remove_to [account, :lists], target: dom_id(self)
  end
  
end
