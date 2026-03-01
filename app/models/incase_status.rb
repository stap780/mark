# frozen_string_literal: true

class IncaseStatus < ApplicationRecord
  belongs_to :account
  has_many :incases, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: { scope: :account_id }
  validates :name, presence: true
  validates :color, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :id) }

  before_destroy :ensure_no_incases

  DEFAULT_STATUSES = [
    { key: "new", name: "Новая", color: "bg-blue-100 text-blue-800", position: 1 },
    { key: "in_progress", name: "В работе", color: "bg-yellow-100 text-yellow-800", position: 2 },
    { key: "done", name: "Выполнена", color: "bg-green-100 text-green-800", position: 3 },
    { key: "canceled", name: "Отменена", color: "bg-red-100 text-red-800", position: 4 },
    { key: "closed", name: "Закрыта", color: "bg-gray-100 text-gray-800", position: 5 }
  ].freeze

  def self.ensure_defaults_for(account)
    return if account.incase_statuses.exists?

    DEFAULT_STATUSES.each do |attrs|
      account.incase_statuses.create!(attrs)
    end
  end

  private

  def ensure_no_incases
    return unless incases.exists?

    errors.add(:base, I18n.t("incase_statuses.destroy.has_incases"))
    throw(:abort)
  end
end
