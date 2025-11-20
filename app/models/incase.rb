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

  def self.ransackable_attributes(auth_object = nil)
    Incase.attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[webform client]
  end
end


