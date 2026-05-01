# frozen_string_literal: true

module Campaigns
  class RunService
    def self.call(campaign:)
      new(campaign: campaign).call
    end

    def initialize(campaign:)
      @campaign = campaign
      @account = campaign.account
    end

    def call
      @account.switch_to

      unless @campaign.webform
        Rails.logger.warn("Campaigns::RunService: campaign ##{@campaign.id} has no touch webform")
        return { created: 0, skipped: 0, error: :no_webform }
      end

      default_status = @account.incase_statuses.find_by(key: "new") || @account.incase_statuses.ordered.first
      if default_status.nil?
        Rails.logger.error("Campaigns::RunService: no incase status for account #{@account.id}")
        return { created: 0, skipped: 0, error: :no_status }
      end

      client_ids = SegmentClientIds.call(campaign: @campaign)
      created = 0
      skipped = 0

      client_ids.each do |client_id|
        if dedupe_block?(client_id)
          skipped += 1
          next
        end

        client = @account.clients.find_by(id: client_id)
        next unless client

        @account.incases.create!(
          webform: @campaign.webform,
          client: client,
          incase_status: default_status,
          campaign: @campaign
        )
        created += 1
      end

      @campaign.update_column(:last_run_at, Time.current)
      { created: created, skipped: skipped }
    end

    private

    def dedupe_block?(client_id)
      w = @campaign.dedupe_days
      return false if w.blank? || w.to_i <= 0

      @campaign.incases.where(client_id: client_id).where(created_at: w.days.ago..).exists?
    end
  end
end
