class Message < ApplicationRecord
  include ActionView::RecordIdentifier
  include AccountScoped

  belongs_to :conversation
  belongs_to :account
  belongs_to :client
  belongs_to :user, optional: true

  enum :direction, {
    outgoing: 'outgoing',
    incoming: 'incoming'
  }

  enum :channel, {
    telegram: 'telegram',
    email: 'email',
    sms: 'sms'
  }

  enum :status, {
    sent: 'sent',
    delivered: 'delivered',
    read: 'read',
    failed: 'failed'
  }, default: 'sent'

  validates :conversation_id, :account_id, :client_id, :direction, :channel, :content, presence: true
  validates :subject, presence: true, if: -> { email? }

  scope :outgoing, -> { where(direction: 'outgoing') }
  scope :incoming, -> { where(direction: 'incoming') }
  scope :by_channel, ->(channel) { where(channel: channel) }
  scope :recent, -> { order(created_at: :desc) }

  after_create_commit :update_conversation_timestamps
  after_create_commit :broadcast_append_to_messages

  private

  def update_conversation_timestamps
    conversation.update_timestamps
  end

  def broadcast_append_to_messages
    stream = dom_id(account, dom_id(conversation, :messages))
    # append: в timeline новые сообщения внизу
    broadcast_append_to stream,
                        target: stream,
                        partial: "conversations/message",
                        locals: { message: self, conversation: conversation, current_account: account }
  end
end
