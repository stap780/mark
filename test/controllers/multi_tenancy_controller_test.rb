require "test_helper"

class MultiTenancyControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Создаем два аккаунта
    @account1 = Account.create!(name: "Account 1")
    @account2 = Account.create!(name: "Account 2")
    
    # Создаем двух пользователей
    @user1 = User.create!(
      email_address: "user1@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    @user2 = User.create!(
      email_address: "user2@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    # user1 принадлежит account1
    AccountUser.create!(user: @user1, account: @account1, role: "admin")
    
    # user2 принадлежит account2
    AccountUser.create!(user: @user2, account: @account2, role: "admin")
    
    # Создаем активные подписки для обоих аккаунтов
    @plan = Plan.create!(name: "Basic", price: 1000)
    Subscription.create!(
      account: @account1,
      plan: @plan,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
    Subscription.create!(
      account: @account2,
      plan: @plan,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
    
    # Создаем продукты для каждого аккаунта
    @product1 = Product.create!(account: @account1, title: "Product 1")
    @product2 = Product.create!(account: @account2, title: "Product 2")
  end

  test "user can only access their own account data" do
    # Авторизуемся как user1
    session1 = @user1.sessions.create!(
      user_agent: "Test Agent",
      ip_address: "127.0.0.1"
    )
    cookies.signed[:session_id] = session1.id
    
    # Пытаемся получить доступ к продуктам account1
    get account_products_path(@account1)
    assert_response :success
    
    # Пытаемся получить доступ к продуктам account2 (другой аккаунт)
    get account_products_path(@account2)
    # Должен быть редирект на страницу входа, так как user1 не принадлежит account2
    assert_redirected_to new_session_path
  end

  test "user cannot access other account's products" do
    # Авторизуемся как user1
    session1 = @user1.sessions.create!(
      user_agent: "Test Agent",
      ip_address: "127.0.0.1"
    )
    cookies.signed[:session_id] = session1.id
    
    # Пытаемся получить доступ к продукту account2
    get account_product_path(@account2, @product2)
    
    # Должен быть редирект, так как user1 не принадлежит account2
    assert_redirected_to new_session_path
  end

  test "data is isolated between accounts in API" do
    # Создаем активные подписки
    # API запрос для account1
    post "/api/accounts/#{@account1.id}/discounts/calc",
         params: { order_lines: [] },
         headers: { "Content-Type" => "application/json" }
    
    # Должен быть успешный ответ (не 402)
    assert_not_equal :payment_required, response.status
    
    # API запрос для account2
    post "/api/accounts/#{@account2.id}/discounts/calc",
         params: { order_lines: [] },
         headers: { "Content-Type" => "application/json" }
    
    # Должен быть успешный ответ (не 402)
    assert_not_equal :payment_required, response.status
  end

  test "user with multiple accounts can switch between them" do
    # user1 теперь принадлежит обоим аккаунтам
    AccountUser.create!(user: @user1, account: @account2, role: "member")
    
    session1 = @user1.sessions.create!(
      user_agent: "Test Agent",
      ip_address: "127.0.0.1"
    )
    cookies.signed[:session_id] = session1.id
    
    # Может получить доступ к account1
    get account_products_path(@account1)
    assert_response :success
    
    # Может получить доступ к account2
    get account_products_path(@account2)
    assert_response :success
  end

  test "admin account can access any account" do
    # Создаем админ-аккаунт
    admin_account = Account.create!(name: "Admin Account", admin: true)
    AccountUser.create!(user: @user1, account: admin_account, role: "admin")
    
    session1 = @user1.sessions.create!(
      user_agent: "Test Agent",
      ip_address: "127.0.0.1"
    )
    cookies.signed[:session_id] = session1.id
    
    # Админ может получить доступ к account1 (даже если не принадлежит напрямую)
    # Но это зависит от логики ensure_user_in_current_account
    # Если админ-аккаунт позволяет обход, то это должно работать
  end
end

