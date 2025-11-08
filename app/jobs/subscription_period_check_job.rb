class SubscriptionPeriodCheckJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting subscription period check at #{Time.current}"
    
    # Находим подписки, у которых период истек
    expired_subscriptions = Subscription
      .where(status: [:active, :trialing])
      .where("current_period_end < ?", Time.current)
    
    count = 0
    expired_subscriptions.find_each do |subscription|
      subscription.update!(status: :canceled)
      count += 1
      Rails.logger.info "  ✓ Canceled subscription #{subscription.id} for account #{subscription.account_id} (period ended: #{subscription.current_period_end.strftime('%d.%m.%Y %H:%M')})"
    end
    
    if count > 0
      Rails.logger.info "Total expired subscriptions canceled: #{count}"
    else
      Rails.logger.info "No expired subscriptions found"
    end
    
    Rails.logger.info "Subscription period check completed at #{Time.current}"
  end
end

