require "test_helper"

class MultiTenancyTest < ActiveSupport::TestCase
  setup do
    # Создаем два аккаунта
    @account1 = Account.create!(name: "Account 1")
    @account2 = Account.create!(name: "Account 2")
    
    # Создаем пользователя
    @user = User.create!(
      email_address: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    # Пользователь принадлежит обоим аккаунтам
    AccountUser.create!(user: @user, account: @account1, role: "admin")
    AccountUser.create!(user: @user, account: @account2, role: "member")
  end

  test "user can belong to multiple accounts" do
    assert_equal 2, @user.accounts.count
    assert_includes @user.accounts, @account1
    assert_includes @user.accounts, @account2
  end

  test "data isolation between accounts" do
    # Создаем продукты для каждого аккаунта
    Account.current = @account1
    product1 = Product.create!(account: @account1, title: "Product 1")
    
    Account.current = @account2
    product2 = Product.create!(account: @account2, title: "Product 2")
    
    # Проверяем изоляцию через AccountScoped
    Account.current = @account1
    assert_equal 1, Product.count
    assert_includes Product.all, product1
    assert_not_includes Product.all, product2
    
    Account.current = @account2
    assert_equal 1, Product.count
    assert_includes Product.all, product2
    assert_not_includes Product.all, product1
  end

  test "user can access only their accounts" do
    # Пользователь может получить доступ только к своим аккаунтам
    user_accounts = @user.accounts
    assert_includes user_accounts, @account1
    assert_includes user_accounts, @account2
    
    # Создаем третий аккаунт, к которому пользователь не принадлежит
    account3 = Account.create!(name: "Account 3")
    assert_not_includes user_accounts, account3
  end

  test "account scoped models are isolated" do
    # Создаем клиентов для разных аккаунтов
    client1 = Client.create!(account: @account1, name: "Client 1")
    client2 = Client.create!(account: @account2, name: "Client 2")
    
    # Проверяем изоляцию
    Account.current = @account1
    assert_equal 1, Client.count
    assert_includes Client.all, client1
    
    Account.current = @account2
    assert_equal 1, Client.count
    assert_includes Client.all, client2
  end

  test "subscriptions are account-specific" do
    plan = Plan.create!(name: "Basic", price: 1000, trial_days: 0)
    
    # Создаем подписки для разных аккаунтов
    subscription1 = Subscription.create!(
      account: @account1,
      plan: plan,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
    
    subscription2 = Subscription.create!(
      account: @account2,
      plan: plan,
      status: :active,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
    
    # Проверяем, что подписки изолированы
    assert_equal 1, @account1.subscriptions.count
    assert_equal 1, @account2.subscriptions.count
    assert_equal subscription1, @account1.current_subscription
    assert_equal subscription2, @account2.current_subscription
  end

  test "user role is account-specific" do
    # Пользователь - админ в account1, но не в account2
    account_user1 = AccountUser.find_by(user: @user, account: @account1)
    account_user2 = AccountUser.find_by(user: @user, account: @account2)
    
    assert_equal "admin", account_user1.role
    assert_equal "member", account_user2.role
    
    assert @user.admin_in_account?(@account1)
    assert_not @user.admin_in_account?(@account2)
  end
end

