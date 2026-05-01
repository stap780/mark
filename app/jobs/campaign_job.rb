# frozen_string_literal: true

class CampaignJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(campaign, expected_at = nil)
    return unless campaign&.active? && campaign.recurring?

    if expected_at.present? && campaign.scheduled_for.present?
      return unless campaign.scheduled_for.to_i == expected_at
    end

    account = campaign.account
    Account.switch_to(account.id)

    result = Campaigns::RunService.call(campaign: campaign)
    Rails.logger.info("CampaignJob: campaign_id=#{campaign.id} result=#{result.inspect}")

    campaign.reload
    if campaign.active? && campaign.recurring? && campaign.time.present?
      campaign.enqueue_next_run!(from_time: Time.zone.now)
    end
  end
end
