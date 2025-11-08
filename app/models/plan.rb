class Plan < ApplicationRecord
  enum :interval, { 
    monthly: "monthly", 
    three_months: "three_months", 
    six_months: "six_months", 
    twelve_months: "twelve_months" 
  }, default: :monthly

  has_many :subscriptions

  before_destroy :check_for_subscriptions

  validates :name, presence: true, uniqueness: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :trial_days, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }

  # Возвращает количество месяцев для интервала
  def interval_months
    case interval
    when 'monthly'
      1
    when 'three_months'
      3
    when 'six_months'
      6
    when 'twelve_months'
      12
    else
      1 # По умолчанию 1 месяц
    end
  end

  private

  def check_for_subscriptions
    if subscriptions.exists?
      errors.add(:base, 'Cannot delete plan with existing subscriptions')
      throw :abort
    end
  end
end

