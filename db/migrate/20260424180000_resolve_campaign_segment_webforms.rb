# frozen_string_literal: true

class ResolveCampaignSegmentWebforms < ActiveRecord::Migration[8.0]
  def up
    say_with_time "Migrating legacy incase_reference_webform rules → campaigns.webform_id" do
      CampaignFilterRule.where(field: "incase_reference_webform").find_each do |rule|
        campaign = Campaign.find_by(id: rule.campaign_id)
        next unless campaign

        wf_id = rule.value.to_s.strip.to_i
        next if wf_id.zero?

        if campaign.webform_id.blank?
          campaign.update_columns(webform_id: wf_id)
        end
      end
    end

    say_with_time "Removing incase_reference_webform rows" do
      CampaignFilterRule.where(field: "incase_reference_webform").delete_all
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
