require "test_helper"

class Admin::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # super-admin account
    @admin_account = Account.create!(name: "Admin", admin: true)
    @user = User.create!(
      email_address: "admin@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    AccountUser.create!(user: @user, account: @admin_account, role: "admin")

    # partner account to check
    @partner_account = Account.create!(
      name: "Partner Account",
      partner: true,
      settings: { "apps" => ["inswatch"] }
    )

    # login
    session = @user.sessions.create!(user_agent: "Test Agent", ip_address: "127.0.0.1")
    cookies.signed[:session_id] = session.id
  end

  test "super admin can trigger check_subscription and gets success flash" do
    result = PartnerBillingCheck::Result.new(
      success?: true,
      status: "active",
      paid_till: 10.days.from_now.to_date.to_s,
      trial_expired_at: nil,
      blocked: false,
      error: nil
    )

    PartnerBillingCheck.stub(:call, result) do
      post check_subscription_admin_account_path(@partner_account)
    end

    assert_redirected_to admin_account_path(@partner_account)
    assert flash[:success].present?
  end

  test "handles PartnerBillingCheck failure with error flash" do
    result = PartnerBillingCheck::Result.new(
      success?: false,
      status: nil,
      paid_till: nil,
      trial_expired_at: nil,
      blocked: nil,
      error: "some error"
    )

    PartnerBillingCheck.stub(:call, result) do
      post check_subscription_admin_account_path(@partner_account)
    end

    assert_redirected_to admin_account_path(@partner_account)
    assert flash[:error].present?
  end
end

