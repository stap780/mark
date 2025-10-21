class Discount < ApplicationRecord
  include ActionView::RecordIdentifier
  include AccountScoped

  belongs_to :account
  acts_as_list scope: :account_id, column: :position

  validates :title, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  # Hotwire broadcasts

  after_create_commit do
    broadcast_append_to dom_id(account, :discounts),
                        target: dom_id(account, :discounts),
                        partial: "discounts/discount",
                        locals: { discount: self, current_account: account }
  end

  after_update_commit do
    broadcast_replace_to dom_id(account, :discounts),
                        target: dom_id(account, dom_id(self)),
                        partial: "discounts/discount",
                        locals: { discount: self, current_account: account }
  end

  after_destroy_commit do
    broadcast_remove_to dom_id(account, :discounts), target: dom_id(account, dom_id(self))
  end

end