# frozen_string_literal: true

module CampaignFilterRulesHelper
  include AutomationRulesHelper

  VF = "campaigns.filter_fields"

  def campaign_filter_segment_webforms_for(rule)
    account = rule.campaign&.account
    account ||= current_account
    return Webform.none if account.blank?

    Webform.unscoped.where(account_id: account.id).order(:title)
  end

  def campaign_filter_rule_field_label(field_key)
    t("#{VF}.fields.#{field_key}", default: field_key.to_s.humanize)
  end

  def campaign_filter_rule_field_select_options
    CampaignFilterRule::FIELDS.map do |field_key|
      [campaign_filter_rule_field_label(field_key), field_key]
    end
  end

  def campaign_filter_rule_operator_select_options(field)
    cfg = CampaignFilterRule::FIELD_CONFIG[field.to_s]
    ops = cfg ? cfg[:operators] : %w[equals]
    ops.map do |op|
      label = t("#{VF}.operators.#{op}", default: operator_label(op))
      [label, op]
    end
  end

  def campaign_filter_rule_segment_value_type(field_key)
    CampaignFilterRule::FIELD_CONFIG[field_key.to_s]&.[](:type) || "string"
  end
end
