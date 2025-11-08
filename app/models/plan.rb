class Plan < ApplicationRecord
  enum :interval, { monthly: "monthly" }, default: :monthly

  has_many :subscriptions

  before_destroy :check_for_subscriptions

  validates :name, presence: true, uniqueness: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :trial_days, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }

  private

  def check_for_subscriptions
    if subscriptions.exists?
      errors.add(:base, 'Cannot delete plan with existing subscriptions')
      throw :abort
    end
  end
end

