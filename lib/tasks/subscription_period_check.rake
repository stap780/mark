namespace :subscriptions do
  desc "Check and update expired subscriptions (period ended)"
  task check_periods: :environment do
    puts "Starting subscription period check at #{Time.current}"
    
    # Находим подписки, у которых период истек
    expired_subscriptions = Subscription
      .where(status: [:active, :trialing])
      .where("current_period_end < ?", Time.current)
    
    count = 0
    expired_subscriptions.find_each do |subscription|
      subscription.update!(status: :canceled)
      count += 1
      puts "  ✓ Canceled subscription #{subscription.id} for account #{subscription.account_id} (period ended: #{subscription.current_period_end.strftime('%d.%m.%Y %H:%M')})"
    end
    
    if count > 0
      puts "Total expired subscriptions canceled: #{count}"
    else
      puts "No expired subscriptions found"
    end
    
    puts "Subscription period check completed at #{Time.current}"
  end
end

