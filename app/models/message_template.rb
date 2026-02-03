class MessageTemplate < ApplicationRecord
  include AccountScoped
  belongs_to :account
  has_many :automation_messages

  enum :channel, {
    email: 'email',
    sms: 'sms',
    telegram: 'telegram'
  }

  validates :title, :channel, :content, presence: true
end

