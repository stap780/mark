require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Test Account")
    @plan = Plan.create!(
      name: "Test Plan",
      price: 1000,
      interval: :monthly,
      trial_days: 0,
      active: true
    )
  end

  test "activates subscription when payment succeeds for incomplete subscription" do
    # Create an incomplete subscription with expired period
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :incomplete,
      current_period_start: 2.months.ago,
      current_period_end: 1.month.ago
    )

    # Create a payment with pending status
    payment = Payment.create!(
      subscription: subscription,
      amount: @plan.price,
      status: :pending,
      processor: :paymaster
    )

    # Update payment status to succeeded
    payment.update!(status: :succeeded)

    # Reload subscription to get updated status
    subscription.reload

    # Assertions
    assert_equal "succeeded", payment.status
    assert_equal "active", subscription.status
    assert_not_nil subscription.current_period_start
    assert_not_nil subscription.current_period_end
    assert_not_nil payment.paid_at
    assert payment.paid_at <= Time.current
  end

  test "activates subscription when payment succeeds for subscription with future period dates" do
    # Create an incomplete subscription with future period dates
    future_start = 1.month.from_now
    future_end = 2.months.from_now
    
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :incomplete,
      current_period_start: future_start,
      current_period_end: future_end
    )

    # Create and succeed payment
    payment = Payment.create!(
      subscription: subscription,
      amount: @plan.price,
      status: :pending,
      processor: :invoice
    )

    payment.update!(status: :succeeded)
    subscription.reload

    # Should use the pre-set period dates, not overwrite them
    assert_equal "active", subscription.status
    assert_equal future_start.to_i, subscription.current_period_start.to_i
    assert_equal future_end.to_i, subscription.current_period_end.to_i
  end

  test "does not activate subscription when payment fails" do
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :incomplete,
      current_period_start: 1.month.ago,
      current_period_end: Time.current
    )

    # Create a pending payment first to prevent cancellation
    pending_payment = Payment.create!(
      subscription: subscription,
      amount: @plan.price,
      status: :pending,
      processor: :invoice
    )

    payment = Payment.create!(
      subscription: subscription,
      amount: @plan.price,
      status: :pending,
      processor: :paymaster
    )

    # Update payment status to failed
    payment.update!(status: :failed)
    subscription.reload

    # Subscription should remain incomplete because there's still a pending payment
    assert_equal "failed", payment.status
    assert_equal "incomplete", subscription.status
  end

  test "cancels subscription when all payments fail and no pending payments" do
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :incomplete,
      current_period_start: 1.month.ago,
      current_period_end: Time.current
    )

    # Create first failed payment
    payment1 = Payment.create!(
      subscription: subscription,
      amount: @plan.price,
      status: :pending,
      processor: :paymaster
    )
    payment1.update!(status: :failed)

    # Create second failed payment
    payment2 = Payment.create!(
      subscription: subscription,
      amount: @plan.price,
      status: :pending,
      processor: :invoice
    )
    payment2.update!(status: :failed)

    subscription.reload

    # Subscription should be canceled when all payments failed
    assert_equal "canceled", subscription.status
  end

  test "keeps subscription incomplete when payment fails but pending payments exist" do
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :incomplete,
      current_period_start: 1.month.ago,
      current_period_end: Time.current
    )

    # Create pending payment FIRST
    pending_payment = Payment.create!(
      subscription: subscription,
      amount: @plan.price,
      status: :pending,
      processor: :invoice
    )

    # Create failed payment
    failed_payment = Payment.create!(
      subscription: subscription,
      amount: @plan.price,
      status: :pending,
      processor: :paymaster
    )
    failed_payment.update!(status: :failed)

    subscription.reload

    # Subscription should remain incomplete because there's a pending payment
    assert_equal "incomplete", subscription.status
  end

  test "does not activate already active subscription when payment succeeds" do
    # Create an active subscription
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )

    payment = Payment.create!(
      subscription: subscription,
      amount: @plan.price,
      status: :pending,
      processor: :paymaster
    )

    payment.update!(status: :succeeded)
    subscription.reload

    # Subscription should remain active (not change)
    assert_equal "active", subscription.status
  end

  test "sets paid_at timestamp when payment succeeds" do
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :incomplete,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )

    payment = Payment.create!(
      subscription: subscription,
      amount: @plan.price,
      status: :pending,
      processor: :cash
    )

    assert_nil payment.paid_at

    payment.update!(status: :succeeded)
    payment.reload

    assert_not_nil payment.paid_at
    assert payment.paid_at <= Time.current
  end

  test "activates expired subscription when payment succeeds" do
    # Create a subscription that has expired (incomplete with expired period)
    expired_end = 1.month.ago
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :incomplete,
      current_period_start: 2.months.ago,
      current_period_end: expired_end
    )

    # Verify subscription period has expired
    assert subscription.current_period_end < Time.current

    # Create and succeed payment
    payment = Payment.create!(
      subscription: subscription,
      amount: @plan.price,
      status: :pending,
      processor: :paymaster
    )

    payment.update!(status: :succeeded)
    subscription.reload

    # Subscription should be activated
    assert_equal "active", subscription.status
    assert_not_nil subscription.current_period_start
    assert_not_nil subscription.current_period_end
    # Period dates should be set (using existing dates or current time)
    # The logic uses existing current_period_start if present, or Time.current
    assert subscription.current_period_start.present?
    assert subscription.current_period_end > subscription.current_period_start
  end

  test "account subscription_active? returns true after payment activates subscription" do
    # Create a subscription with future period dates to ensure it's active after payment
    future_start = Time.current
    future_end = 1.month.from_now
    
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :incomplete,
      current_period_start: future_start,
      current_period_end: future_end
    )

    # Before payment, subscription should not be active (status is incomplete)
    assert_not @account.subscription_active?

    # Create and succeed payment
    payment = Payment.create!(
      subscription: subscription,
      amount: @plan.price,
      status: :pending,
      processor: :invoice
    )

    payment.update!(status: :succeeded)
    subscription.reload
    @account.reload

    # After payment, subscription should be active
    assert subscription.active?
    assert subscription.current_period_end > Time.current
    assert @account.subscription_active?
  end

  test "can activate new subscription when old subscription exists but new starts after old ends" do
    # Create active subscription
    old_subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )

    # Create new subscription that starts after old ends
    new_subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :incomplete,
      current_period_start: old_subscription.current_period_end,
      current_period_end: old_subscription.current_period_end + 1.month
    )

    # Create and succeed payment for new subscription
    payment = Payment.create!(
      subscription: new_subscription,
      amount: @plan.price,
      status: :pending,
      processor: :invoice
    )

    # Payment should succeed and activate new subscription
    payment.update!(status: :succeeded)
    new_subscription.reload
    old_subscription.reload

    # New subscription should be active
    assert_equal "active", new_subscription.status

    # Old subscription should remain active (not canceled)
    assert_equal "active", old_subscription.status

    # current_subscription should return old subscription (its period is active now)
    current = @account.current_subscription
    assert_equal old_subscription.id, current.id
  end

  test "new subscription becomes current when old subscription period ends" do
    # Create old subscription that ended in the past
    old_subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :active,
      current_period_start: 2.months.ago,
      current_period_end: 1.month.ago
    )

    # Create new subscription that starts now (after old ended)
    new_subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :incomplete,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )

    # Activate new subscription
    payment = Payment.create!(
      subscription: new_subscription,
      amount: @plan.price,
      status: :pending,
      processor: :invoice
    )
    payment.update!(status: :succeeded)
    new_subscription.reload

    # Check subscription_active? - should cancel old and find new
    assert @account.subscription_active?

    # current_subscription should return new subscription
    current = @account.current_subscription
    assert_equal new_subscription.id, current.id

    # Old subscription should be canceled
    old_subscription.reload
    assert_equal "canceled", old_subscription.status
  end
end

