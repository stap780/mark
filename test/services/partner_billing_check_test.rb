require "test_helper"

class PartnerBillingCheckTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(
      name: "Partner Account",
      partner: true,
      settings: { "apps" => ["inswatch"] }
    )

    Account.switch_to(@account.id)

    @insale = Insale.create!(
      account: @account,
      api_link: "https://example.myinsales.ru",
      api_key: "test_key",
      api_password: "test_password"
    )
  end

  def stub_recurring_charge(data)
    charge = Struct.new(:attributes).new(data)
    InsalesApi::RecurringApplicationCharge.stub(:find, charge) do
      yield
    end
  end

  test "creates or updates active subscription when paid_till is in the future" do
    paid_till_date = 10.days.from_now.to_date

    data = {
      "monthly" => "799.0",
      "paid_till" => paid_till_date.to_s,
      "trial_expired_at" => nil,
      "blocked" => false
    }

    stub_recurring_charge(data) do
      result = PartnerBillingCheck.call(@account, app_key: "inswatch")

      assert result.success?, "expected success, got error: #{result.error.inspect}"
      assert_equal "active", result.status
      assert_equal paid_till_date.to_s, result.paid_till

      plan = Plan.find_by(name: "inswatch 799")
      refute_nil plan

      subscription = @account.subscriptions.find_by(plan: plan)
      refute_nil subscription
      assert_equal "active", subscription.status
      assert_not_nil subscription.current_period_end
      assert_equal paid_till_date, subscription.current_period_end.to_date
    end
  end

  test "cancels subscription when blocked" do
    data = {
      "monthly" => "799.0",
      "paid_till" => 5.days.ago.to_date.to_s,
      "trial_expired_at" => nil,
      "blocked" => true
    }

    stub_recurring_charge(data) do
      result = PartnerBillingCheck.call(@account, app_key: "inswatch")

      assert result.success?, "expected success, got error: #{result.error.inspect}"

      plan = Plan.find_by(name: "inswatch 799")
      subscription = @account.subscriptions.find_by(plan: plan)
      refute_nil subscription
      assert_equal "canceled", subscription.status
    end
  end
end

