class Conversation < ApplicationRecord
  include AccountScoped
  include ActionView::RecordIdentifier

  belongs_to :account
  belongs_to :client
  belongs_to :incase, optional: true
  belongs_to :user, optional: true

  has_many :messages, dependent: :destroy

  enum :status, {
    active: 'active',
    closed: 'closed',
    archived: 'archived'
  }, default: 'active'

  # Новый активный диалог (в т.ч. из вебхука Telegram) появляется в списке без перезагрузки
  after_create_commit :broadcast_prepend_to_conversations_list
  # При новом сообщении обновляем превью и время в пункте списка и даём индикатор «новое»
  after_update_commit :broadcast_conversation_list_item_if_new_message

  scope :active, -> { where(status: 'active') }
  scope :waiting_response, -> { where.not(last_outgoing_at: nil).where('last_incoming_at IS NULL OR last_outgoing_at > last_incoming_at') }
  scope :with_recent_messages, -> { where('last_message_at > ?', 7.days.ago) }

  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[client incase user messages]
  end

  def waiting_for_response?
    last_outgoing_at.present? && (last_incoming_at.nil? || last_outgoing_at > last_incoming_at)
  end

  def has_unread_incoming?
    last_incoming_at.present? && (read_at.nil? || last_incoming_at > read_at)
  end

  def mark_as_read!
    update!(read_at: Time.current)
  end

  def needs_follow_up?(days: 3)
    return false unless last_outgoing_at.present?
    return false if last_incoming_at.present? && last_incoming_at > last_outgoing_at
    (Time.current - last_outgoing_at) > days.days
  end

  def update_timestamps
    last_msg = messages.order(created_at: :desc).first
    return unless last_msg

    self.last_message_at = last_msg.created_at
    self.last_outgoing_at = messages.outgoing.maximum(:created_at)
    self.last_incoming_at = messages.incoming.maximum(:created_at)
    save if changed?
  end

  def broadcast_prepend_to_conversations_list
    return unless active?
    streams = [[dom_id(account), :conversations, "active"], [dom_id(account), :conversations, "all"]]
    partial = "conversations/conversation"
    locals = { conversation: self, current_account: account }
    streams.each do |stream|
      broadcast_remove_to stream, target: dom_id(account, :conversations_empty)
      broadcast_prepend_to stream, target: dom_id(account, :conversations), partial: partial, locals: locals
    end
  end

  def broadcast_conversation_list_item_if_new_message
    return unless active?
    return unless saved_change_to_last_message_at?
    broadcast_list_item_update
  end

  def broadcast_replace_to_each_stream(streams, target)
    partial = "conversations/conversation"
    locals = { conversation: self, current_account: account }
    streams.each do |stream|
      broadcast_replace_to stream, target: target, partial: partial, locals: locals
    end
  end

  def broadcast_list_item_update
    return unless active?
    item_target = [dom_id(self), dom_id(account)].join("_")
    streams = [[dom_id(account), :conversations, "active"], [dom_id(account), :conversations, "all"]]
    broadcast_replace_to_each_stream(streams, item_target)
  end
end
