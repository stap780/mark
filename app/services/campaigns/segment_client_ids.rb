# frozen_string_literal: true

module Campaigns
  # Client IDs matching all campaign filter rules (AND between rules).
  class SegmentClientIds
    def self.call(campaign:)
      new(campaign: campaign).call
    end

    def initialize(campaign:)
      @campaign = campaign
      @account = campaign.account
    end

    def call
      base_segment_client_ids.tap { |ids| apply_opt_in_rules!(ids) }
    end

    private

    def rules
      @campaign.campaign_filter_rules.to_a
    end

    def base_segment_client_ids
      r = rules
      wf_ids = r.select { |x| x.field == "incase_reference_webform" }.filter_map { |x| x.value.to_s.strip.to_i }.reject(&:zero?).uniq
      wf_ids = @account.webforms.pluck(:id) if wf_ids.empty?

      min_rr = r.find { |x| x.field == "incase_days_min" }
      max_rr = r.find { |x| x.field == "incase_days_max" }
      min_d = min_rr ? min_rr.value.to_s.strip.to_i : 0
      max_d = max_rr ? max_rr.value.to_s.strip.to_i : 36_500

      return [] if wf_ids.empty?
      return [] if min_d.negative? || max_d.negative? || min_d > max_d

      rel = @account.incases.where(webform_id: wf_ids)
      rows = rel.group("incases.client_id").pluck("incases.client_id", Arel.sql("MAX(incases.created_at)"))

      ids = rows.filter_map do |client_id, last_at|
        next unless last_at

        days = (Date.current - last_at.in_time_zone.to_date).to_i
        next unless days.between?(min_d, max_d)

        client_id
      end

      email_rule = rules.find { |x| x.field == "client_email_contains" && x.target_client? }
      if email_rule && email_rule.value.present?
        needle = email_rule.value.to_s.downcase.strip
        like = "%#{ActiveRecord::Base.sanitize_sql_like(needle)}%"
        ids &= @account.clients.where("LOWER(email) LIKE ?", like).pluck(:id)
      end

      ids.uniq
    end

    def apply_opt_in_rules!(ids)
      rule = rules.find { |r| r.field == "client_email_marketing_opt_in" && r.target_client? }
      return unless rule

      unless @account.clients.column_names.include?("email_marketing_opt_in")
        Rails.logger.warn("Campaigns::SegmentClientIds: email_marketing_opt_in missing on clients; skip opt-in rule")
        return
      end

      desired = ActiveModel::Type::Boolean.new.cast(rule.value)
      opted = @account.clients.where(id: ids).where(email_marketing_opt_in: true).pluck(:id)
      opted_out = @account.clients.where(id: ids).where(email_marketing_opt_in: false).pluck(:id)
      ids.replace(desired ? opted : opted_out)
      ids.uniq!
    end
  end
end
