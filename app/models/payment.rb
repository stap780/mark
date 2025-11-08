class Payment < ApplicationRecord
  enum :status, {
    succeeded: "succeeded",
    failed: "failed",
    pending: "pending"
  }, default: :pending

  enum :processor, {
    # paymaster: "paymaster",
    invoice: "invoice",
    cash: "cash"
  }

  belongs_to :subscription

  after_update :update_subscription_status, if: :saved_change_to_status?

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :processor, presence: true

  scope :succeeded, -> { where(status: :succeeded) }
  scope :failed, -> { where(status: :failed) }
  scope :pending, -> { where(status: :pending) }
  scope :paymaster, -> { where(processor: :paymaster) }
  scope :invoice, -> { where(processor: :invoice) }
  scope :cash, -> { where(processor: :cash) }

  def self.ransackable_attributes(auth_object = nil)
    Payment.attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    ["subscription"]
  end

  def paymaster?
    processor == "paymaster"
  end

  def invoice?
    processor == "invoice"
  end

  def cash?
    processor == "cash"
  end

  private

  def update_subscription_status
    subscription = self.subscription
    return unless subscription

    if status == "succeeded" && subscription.incomplete?
      # Активируем подписку при успешной оплате
      # Используем уже установленные даты периода из подписки, если они есть
      # Если дат нет - устанавливаем период от текущего времени с учетом интервала плана
      period_start = subscription.current_period_start || Time.current
      period_months = subscription.plan&.interval_months || 1
      period_end = subscription.current_period_end || (period_start + period_months.months)
      
      subscription.update!(
        status: :active,
        current_period_start: period_start,
        current_period_end: period_end
      )
      self.update_column(:paid_at, Time.current) unless paid_at
    elsif status == "failed"
      # Если платеж провалился:
      # - Подписка остается incomplete (если еще не была активирована)
      # - Если все платежи провалились и нет succeeded - отменяем подписку
      if subscription.incomplete? && subscription.payments.where(status: :succeeded).empty?
        # Проверяем, есть ли еще pending платежи
        if subscription.payments.where(status: :pending).empty?
          # Все платежи либо failed, либо нет платежей - отменяем подписку
          subscription.update!(status: :canceled)
        end
        # Если есть pending платежи - оставляем incomplete
      end
    end
  end
end