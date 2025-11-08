require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Test Account")
    @plan_monthly = Plan.create!(name: "Monthly", price: 1000, interval: :monthly, trial_days: 0)
    @plan_three_months = Plan.create!(name: "Three Months", price: 2500, interval: :three_months, trial_days: 0)
  end

  test "can activate new subscription if it starts after existing subscription ends" do
    # Создаем активную подписку на 1 месяц
    old_subscription = Subscription.create!(
      account: @account,
      plan: @plan_monthly,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )

    # Создаем новую подписку на 3 месяца, которая начинается после окончания старой
    new_subscription = Subscription.new(
      account: @account,
      plan: @plan_three_months,
      status: :active,
      current_period_start: old_subscription.current_period_end,
      current_period_end: old_subscription.current_period_end + 3.months
    )

    # Валидация должна разрешить активацию
    assert new_subscription.valid?
    assert new_subscription.save
  end

  test "cannot activate new subscription if periods overlap" do
    # Создаем активную подписку
    old_subscription = Subscription.create!(
      account: @account,
      plan: @plan_monthly,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )

    # Создаем новую подписку, которая начинается до окончания старой
    new_subscription = Subscription.new(
      account: @account,
      plan: @plan_three_months,
      status: :active,
      current_period_start: 2.weeks.from_now, # Начинается до окончания старой
      current_period_end: 2.weeks.from_now + 3.months
    )

    # Валидация должна заблокировать активацию
    assert_not new_subscription.valid?
    assert_includes new_subscription.errors[:status], I18n.t('activerecord.errors.models.subscription.attributes.status.only_one_active_subscription', default: 'only one active subscription')
  end

  test "old subscription remains active until its period ends" do
    # Создаем активную подписку на 1 месяц
    old_subscription = Subscription.create!(
      account: @account,
      plan: @plan_monthly,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )

    # Создаем и активируем новую подписку на 3 месяца
    new_subscription = Subscription.create!(
      account: @account,
      plan: @plan_three_months,
      status: :active,
      current_period_start: old_subscription.current_period_end,
      current_period_end: old_subscription.current_period_end + 3.months
    )

    # Старая подписка должна остаться активной
    old_subscription.reload
    assert_equal "active", old_subscription.status

    # current_subscription должен вернуть старую подписку (её период активен сейчас)
    current = @account.current_subscription
    assert_equal old_subscription.id, current.id
  end

  test "new subscription becomes current when old subscription ends" do
    # Создаем активную подписку, которая заканчивается в прошлом (имитируем истекшую)
    old_subscription = Subscription.create!(
      account: @account,
      plan: @plan_monthly,
      status: :active,
      current_period_start: 2.months.ago,
      current_period_end: 1.month.ago
    )

    # Создаем новую подписку, которая начинается после окончания старой
    new_subscription = Subscription.create!(
      account: @account,
      plan: @plan_three_months,
      status: :active,
      current_period_start: old_subscription.current_period_end,
      current_period_end: old_subscription.current_period_end + 3.months
    )

    # Проверяем subscription_active? - должна отменить старую и найти новую
    # Но новая начинается в прошлом (1 месяц назад), так что она тоже истекла
    # Нужно создать новую подписку с периодом в будущем
    new_subscription.update!(
      current_period_start: Time.current,
      current_period_end: 3.months.from_now
    )

    # subscription_active? должна найти новую подписку
    assert @account.subscription_active?
    current = @account.current_subscription
    assert_equal new_subscription.id, current.id

    # Старая подписка должна быть отменена
    old_subscription.reload
    assert_equal "canceled", old_subscription.status
  end

  test "current_subscription returns subscription with active period now" do
    # Создаем подписку с активным периодом сейчас
    active_subscription = Subscription.create!(
      account: @account,
      plan: @plan_monthly,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )

    # Создаем подписку, которая начнется в будущем
    future_subscription = Subscription.create!(
      account: @account,
      plan: @plan_three_months,
      status: :active,
      current_period_start: 1.month.from_now,
      current_period_end: 4.months.from_now
    )

    # current_subscription должен вернуть подписку с активным периодом сейчас
    current = @account.current_subscription
    assert_equal active_subscription.id, current.id
  end

  test "current_subscription returns future subscription when current period ended" do
    # Создаем подписку, которая уже закончилась
    old_subscription = Subscription.create!(
      account: @account,
      plan: @plan_monthly,
      status: :active,
      current_period_start: 2.months.ago,
      current_period_end: 1.month.ago
    )

    # Создаем подписку, которая начнется в будущем
    future_subscription = Subscription.create!(
      account: @account,
      plan: @plan_three_months,
      status: :active,
      current_period_start: 1.month.from_now,
      current_period_end: 4.months.from_now
    )

    # current_subscription должен вернуть подписку, которая начнется в будущем
    current = @account.current_subscription
    assert_equal future_subscription.id, current.id
  end

  test "subscription_active? returns true only for subscription with active period now" do
    # Создаем подписку с активным периодом сейчас
    active_subscription = Subscription.create!(
      account: @account,
      plan: @plan_monthly,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )

    assert @account.subscription_active?

    # Создаем подписку, которая начнется в будущем
    future_subscription = Subscription.create!(
      account: @account,
      plan: @plan_three_months,
      status: :active,
      current_period_start: 1.month.from_now,
      current_period_end: 4.months.from_now
    )

    # subscription_active? должна вернуть true (есть активная сейчас)
    assert @account.subscription_active?
  end

  test "subscription_active? returns false when only future subscription exists" do
    # Создаем только подписку, которая начнется в будущем
    future_subscription = Subscription.create!(
      account: @account,
      plan: @plan_three_months,
      status: :active,
      current_period_start: 1.month.from_now,
      current_period_end: 4.months.from_now
    )

    # subscription_active? должна вернуть false (нет активной сейчас)
    assert_not @account.subscription_active?
  end

  test "set_period_dates sets period based on plan interval" do
    # Создаем подписку на 3 месяца
    subscription = Subscription.new(
      account: @account,
      plan: @plan_three_months,
      status: :incomplete
    )

    subscription.valid? # Вызывает set_period_dates

    # Период должен быть 3 месяца
    assert_not_nil subscription.current_period_start
    assert_not_nil subscription.current_period_end
    assert_equal 3.months, subscription.current_period_end - subscription.current_period_start
  end

  test "set_period_dates sets period after existing subscription ends" do
    # Создаем активную подписку
    existing = Subscription.create!(
      account: @account,
      plan: @plan_monthly,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )

    # Создаем новую подписку на 3 месяца
    new_subscription = Subscription.new(
      account: @account,
      plan: @plan_three_months,
      status: :incomplete
    )

    new_subscription.valid? # Вызывает set_period_dates

    # Период должен начинаться после окончания существующей подписки
    assert_equal existing.current_period_end.to_i, new_subscription.current_period_start.to_i
    assert_equal 3.months, new_subscription.current_period_end - new_subscription.current_period_start
  end
end

