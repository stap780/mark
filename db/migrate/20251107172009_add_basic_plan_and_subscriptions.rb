class AddBasicPlanAndSubscriptions < ActiveRecord::Migration[8.0]
  def up
    # Create or update basic plan with 30-day trial period
    basic_plan = Plan.find_or_create_by!(name: "Basic") do |plan|
      plan.price = 1000
      plan.interval = "monthly"
      plan.active = true
      plan.trial_days = 30
    end

    # Update trial_days if plan already exists but has different trial_days
    if basic_plan.trial_days != 30
      basic_plan.update!(trial_days: 30)
    end

    # Create subscriptions for all accounts that don't have an active subscription
    Account.find_each do |account|
      # Skip if account already has an active or trialing subscription
      next if account.subscriptions.where(status: [:active, :trialing]).exists?

      # Calculate trial period dates
      # Start from current time, end after 30 days
      period_start = Time.current
      period_end = period_start + basic_plan.trial_days.days

      # Create subscription with trialing status
      # The before_validation callback will set period dates, but we'll override them
      # to match the trial period (30 days instead of 1 month)
      subscription = Subscription.create!(
        account: account,
        plan: basic_plan,
        status: :trialing
      )

      # Override period dates to match trial period (30 days)
      # Using update_columns to bypass callbacks and validations
      subscription.update_columns(
        current_period_start: period_start,
        current_period_end: period_end
      )
    end
  end

  def down
    # Find the basic plan
    basic_plan = Plan.find_by(name: "Basic")
    return unless basic_plan

    # Delete all subscriptions for the basic plan that are in trialing status
    # (created by this migration)
    Subscription.where(plan: basic_plan, status: :trialing).destroy_all

    # Optionally remove the basic plan (commented out to preserve data)
    # basic_plan.destroy
  end
end
