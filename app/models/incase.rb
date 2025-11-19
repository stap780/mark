class Incase < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :webform
  belongs_to :client

  has_many :items, dependent: :destroy

  enum :status, {
    new: "new",
    in_progress: "in_progress",
    done: "done",
    canceled: "canceled",
    closed: "closed"
  }, prefix: true

  validates :status, presence: true
end


