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
    # Возвращаем подписку, у которой период сейчас активен (текущее время между start и end)
    # Если такой нет, возвращаем подписку, которая начнется в будущем (но уже запланирована)
    # Если и такой нет, возвращаем самую новую активную подписку
    now = Time.current
    
    # Сначала ищем подписку с активным периодом (сейчас)
    active_now = subscriptions.active.find do |sub|
      sub.current_period_start && sub.current_period_end &&
      sub.current_period_start <= now && now <= sub.current_period_end
    end
    return active_now if active_now
    
    # Если нет активной сейчас, ищем подписку, которая начнется в будущем (уже запланирована)
    future_subscription = subscriptions.active.find do |sub|
      sub.current_period_start && sub.current_period_start > now
    end
    return future_subscription if future_subscription
    
    # Если ничего не найдено, возвращаем самую новую активную подписку
    subscriptions.active.order(created_at: :desc).first
  end

  def has_active_subscription?
    subscriptions.active.exists?
  end

  # Проверяет, что у аккаунта есть активная подписка и период не истек
  # Автоматически отменяет подписку, если период истек
  def subscription_active?
    now = Time.current
    
    # Ищем подписку с активным периодом сейчас (текущее время между start и end)
    active_subscription = subscriptions.active.find do |sub|
      sub.current_period_start && sub.current_period_end &&
      sub.current_period_start <= now && now <= sub.current_period_end
    end
    
    # Если есть активная подписка сейчас - возвращаем true
    return true if active_subscription
    
    # Если нет активной сейчас, проверяем истекшие подписки и отменяем их
    expired_subscriptions = subscriptions.active.select do |sub|
      sub.current_period_end && sub.current_period_end < now
    end
    
    expired_subscriptions.each do |sub|
      sub.update!(status: :canceled)
    end
    
    # Возвращаем false, так как нет активной подписки сейчас
    false
  end
end

