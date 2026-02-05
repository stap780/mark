require "test_helper"

class PartnerBillingDailyJobTest < ActiveJob::TestCase
  setup do
    @partner_account = Account.create!(
      name: "Partner Account",
      partner: true,
      settings: { "apps" => ["inswatch"] }
    )

    @non_partner_account = Account.create!(
      name: "Regular Account",
      partner: false
    )
  end

  test "calls PartnerBillingCheck only for partner accounts with supported apps" do
    calls = []

    PartnerBillingCheck.stub(:SUPPORTED_APPS, %w[inswatch]) do
      PartnerBillingCheck.stub(:call, ->(account) { calls << account.id; OpenStruct.new(success?: true) }) do
        perform_enqueued_jobs do
          PartnerBillingDailyJob.perform_now
        end
      end
    end

    assert_includes calls, @partner_account.id
    refute_includes calls, @non_partner_account.id
  end
end

