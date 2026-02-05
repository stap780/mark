class PartnerBillingDailyJob < ApplicationJob
  queue_as :partner_billing_daily

  def perform
    Account.where(partner: true).find_each do |account|
      apps = account.settings.is_a?(Hash) ? Array(account.settings["apps"]) : []
      next unless (apps & PartnerBillingCheck::SUPPORTED_APPS).any?

      result = PartnerBillingCheck.call(account)

      Rails.logger.info(
        "[PartnerBillingDailyJob] account=#{account.id} " \
        "success=#{result.success?} status=#{result.status.inspect} " \
        "paid_till=#{result.paid_till.inspect} error=#{result.error.inspect}"
      )
    end
  end
end

