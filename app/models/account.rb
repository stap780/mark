class Account < ApplicationRecord
  include Billable

  has_many :account_users, dependent: :destroy
  has_many :users, through: :account_users
  has_many :insales, dependent: :destroy
  has_many :swatch_groups, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :lists, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_many :discounts, dependent: :destroy
  has_many :webforms, dependent: :destroy
  has_many :incases, dependent: :destroy
  validates :name, presence: true

  after_create :create_trial_subscription

  # Set current account context
  def self.current
    Thread.current[:current_account_id] ? Account.find(Thread.current[:current_account_id]) : nil
  end

  def self.current=(account)
    Thread.current[:current_account_id] = account&.id
  end

  # Switch to this account context
  def switch_to
    Account.current = self
    self
  end

  # Switch to account by ID
  def self.switch_to(account_id)
    Account.find(account_id).switch_to
  end

  def self.ransackable_attributes(auth_object = nil)
    ["name", "admin", "active", "created_at", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["subscriptions", "users", "account_users"]
  end

  private

  # Создает пробную подписку на 30 дней при создании аккаунта
  def create_trial_subscription
    # Пропускаем для админ-аккаунтов
    return if admin?

    # Пропускаем, если уже есть активная или пробная подписка
    return if subscriptions.where(status: [:active, :trialing]).exists?

    # Находим или создаем план "Basic" с пробным периодом 30 дней
    trial_plan = Plan.find_or_create_by!(name: "Trial") do |plan|
      plan.price = 0
      plan.interval = "monthly"
      plan.active = true
      plan.trial_days = 30
    end

    # Обновляем trial_days, если план уже существует, но имеет другое значение
    if trial_plan.trial_days != 30
      trial_plan.update!(trial_days: 30)
    end

    # Вычисляем даты пробного периода (точно 30 дней)
    period_start = Time.current
    period_end = period_start + 30.days

    # Создаем подписку со статусом trialing
    # set_period_dates установит даты на основе интервала плана (1 месяц),
    # но мы переопределим их на 30 дней
    subscription = subscriptions.create!(
      plan: trial_plan,
      status: :trialing,
      current_period_start: period_start,
      current_period_end: period_end
    )
  end
end


# # Switch to account 5
# Account.switch_to(5)

# # Now all queries are automatically scoped to account 5
# Product.all          # Same as Product.where(account_id: 5)
# Client.all          # Same as Client.where(account_id: 5)
# Product.first       # First product for account 5
# Product.count       # Count of products for account 5
