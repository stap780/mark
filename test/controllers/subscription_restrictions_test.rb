require "test_helper"

class SubscriptionRestrictionsTest < ActionDispatch::IntegrationTest
  setup do
    # Создаем аккаунт
    @account = Account.create!(name: "Test Account")
    
    # Создаем пользователя
    @user = User.create!(
      email_address: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    # Пользователь принадлежит аккаунту
    AccountUser.create!(user: @user, account: @account, role: "admin")
    
    # Создаем план
    @plan = Plan.create!(name: "Basic", price: 1000, trial_days: 0)
    
    # Создаем сессию
    @session = @user.sessions.create!(
      user_agent: "Test Agent",
      ip_address: "127.0.0.1"
    )
  end

  test "web endpoint requires active subscription" do
    # Создаем истекшую подписку
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :canceled,
      current_period_start: 2.months.ago,
      current_period_end: 1.month.ago
    )
    
    # Устанавливаем сессию
    cookies.signed[:session_id] = @session.id
    
    # Пытаемся получить доступ к продуктам
    get account_products_path(@account)
    
    # Должен быть редирект на страницу подписок
    assert_redirected_to account_subscriptions_path(@account)
    assert_equal "Active subscription required. Please subscribe to continue.", flash[:alert]
  end

  test "web endpoint allows access with active subscription" do
    # Создаем активную подписку
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
    
    # Устанавливаем сессию
    cookies.signed[:session_id] = @session.id
    
    # Пытаемся получить доступ к продуктам
    get account_products_path(@account)
    
    # Должен быть успешный доступ (может быть редирект или успешный ответ)
    assert_response :success
  end

  test "API endpoint requires active subscription" do
    # Создаем истекшую подписку
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :canceled,
      current_period_start: 2.months.ago,
      current_period_end: 1.month.ago
    )
    
    # API запрос без сессии
    post "/api/accounts/#{@account.id}/discounts/calc", 
         params: { order_lines: [] },
         headers: { "Content-Type" => "application/json" }
    
    # Должен вернуть 402 Payment Required
    assert_response :payment_required
    json_response = JSON.parse(response.body)
    assert_equal "Subscription required", json_response["error"]
    assert_equal "Active subscription required to access this API endpoint", json_response["message"]
  end

  test "API endpoint allows access with active subscription" do
    # Создаем активную подписку
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
    
    # API запрос без сессии
    post "/api/accounts/#{@account.id}/discounts/calc",
         params: { order_lines: [] },
         headers: { "Content-Type" => "application/json" }
    
    # Должен быть успешный ответ (может быть ошибка в логике, но не 402)
    assert_not_equal :payment_required, response.status
  end

  test "admin account bypasses subscription check" do
    # Создаем админ-аккаунт
    admin_account = Account.create!(name: "Admin Account", admin: true)
    AccountUser.create!(user: @user, account: admin_account, role: "admin")
    
    # Нет подписки
    # Устанавливаем сессию
    cookies.signed[:session_id] = @session.id
    
    # Пытаемся получить доступ
    get account_products_path(admin_account)
    
    # Админ-аккаунт должен иметь доступ без подписки
    assert_response :success
  end

  test "subscription pages are accessible without active subscription" do
    # Нет активной подписки
    # Устанавливаем сессию
    cookies.signed[:session_id] = @session.id
    
    # Пытаемся получить доступ к странице подписок
    get account_subscriptions_path(@account)
    
    # Должен быть успешный доступ
    assert_response :success
  end

  test "expired subscription is automatically canceled" do
    # Создаем подписку с истекшим периодом
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :active,
      current_period_start: 2.months.ago,
      current_period_end: 1.month.ago  # Истек месяц назад
    )
    
    # Проверяем подписку
    assert_not @account.subscription_active?
    
    # Подписка должна быть автоматически отменена
    subscription.reload
    assert_equal "canceled", subscription.status
  end

  test "subscription_active? returns false for expired subscription" do
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :active,
      current_period_start: 2.months.ago,
      current_period_end: 1.month.ago
    )
    
    assert_not @account.subscription_active?
  end

  test "subscription_active? returns true for active subscription" do
    subscription = Subscription.create!(
      account: @account,
      plan: @plan,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
    
    assert @account.subscription_active?
  end
end

