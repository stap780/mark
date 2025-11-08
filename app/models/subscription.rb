class Subscription < ApplicationRecord
  enum :status, {
    active: "active",
    trialing: "trialing",
    canceled: "canceled",
    incomplete: "incomplete"
  }, default: :incomplete

  belongs_to :account
  belongs_to :plan
  has_many :payments, dependent: :destroy

  before_validation :set_period_dates, on: :create

  validates :status, presence: true
  validate :only_one_active_subscription_per_account

  scope :active, -> { where(status: [:active, :trialing]) }
  scope :incomplete, -> { where(status: :incomplete) }
  scope :trialing, -> { where(status: :trialing) }

  def self.ransackable_attributes(auth_object = nil)
    Subscription.attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    ["account", "plan", "payments"]
  end

  def active?
    status.in?(%w[active trialing])
  end

  def canceled?
    status == "canceled"
  end

  private

  def set_period_dates
    return if current_period_start.present? && current_period_end.present?

    # Получаем количество месяцев из интервала плана
    period_months = plan&.interval_months || 1

    existing_subscription = account&.current_subscription
    if existing_subscription && existing_subscription.current_period_end && existing_subscription.current_period_end > Time.current
      # Новая подписка начинается после окончания текущей
      self.current_period_start = existing_subscription.current_period_end
      self.current_period_end = current_period_start + period_months.months
    else
      # Новая подписка начинается сейчас
      self.current_period_start = Time.current
      self.current_period_end = current_period_start + period_months.months
    end
  end

  def only_one_active_subscription_per_account
    return unless active?

    existing_active = account.subscriptions
                            .where(status: [:active, :trialing])
                            .where.not(id: id)
    
    return unless existing_active.exists?

    # Разрешаем активацию новой подписки, если её период начинается после окончания старой
    # Старая подписка остается активной до своего окончания
    existing_active.each do |existing|
      # Если старая подписка уже истекла - разрешаем активацию новой (старая будет отменена автоматически при проверке subscription_active?)
      if existing.current_period_end && existing.current_period_end < Time.current
        next
      end

      # Если новая подписка начинается после окончания старой - разрешаем активацию
      # Старая подписка остается активной, но новая тоже может быть активной (периоды не пересекаются)
      if current_period_start && existing.current_period_end && 
         current_period_start >= existing.current_period_end
        # Периоды не пересекаются - разрешаем обе подписки быть активными
        next
      end

      # Если периоды пересекаются - блокируем активацию
      errors.add(:status, :only_one_active_subscription)
      break
    end
  end
end

