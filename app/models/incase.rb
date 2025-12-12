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

  after_create_commit :trigger_created_event
  after_update_commit :trigger_update_events

  def self.ransackable_attributes(auth_object = nil)
    Incase.attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[webform client]
  end

  private

  def trigger_created_event
    event = "incase.created.#{webform.kind}"
    Automation::Engine.call(
      account: account,
      event: event,
      object: self
    )
    # Также вызываем общее событие
    Automation::Engine.call(
      account: account,
      event: "incase.created",
      object: self
    )
  end

  def trigger_update_events
    if saved_change_to_status?
      Automation::Engine.call(
        account: account,
        event: "incase.status_changed",
        object: self
      )
    else
      Automation::Engine.call(
        account: account,
        event: "incase.updated",
        object: self
      )
    end
  end
end


