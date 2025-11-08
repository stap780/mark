module Billable
  extend ActiveSupport::Concern

  included do
    has_many :subscriptions, dependent: :destroy
    has_many :payments, through: :subscriptions
  end

  def subscribe(plan:, provider_type:, **options)
    gateway = Billing::Gateways::Base.gateway_for(provider_type)
    result = gateway.create_subscription(account: self, plan: plan, **options)
    result[:subscription]
  end

  def current_subscription
    subscriptions.active.order(created_at: :desc).first
  end

  def has_active_subscription?
    subscriptions.active.exists?
  end

  # Проверяет, что у аккаунта есть активная подписка и период не истек
  # Автоматически отменяет подписку, если период истек
  def subscription_active?
    subscription = current_subscription
    return false unless subscription
    return false unless subscription.active?
    
    # Если период истек - автоматически отменяем подписку
    if subscription.current_period_end && subscription.current_period_end < Time.current
      subscription.update!(status: :canceled)
      return false
    end
    
    subscription.current_period_end.nil? || subscription.current_period_end > Time.current
  end
end

