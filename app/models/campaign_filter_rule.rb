# frozen_string_literal: true

class CampaignFilterRule < ApplicationRecord
  belongs_to :campaign
  has_one :account, through: :campaign

  CLIENT_FIELDS = %w[client_email_contains client_email_marketing_opt_in].freeze

  FIELD_CONFIG = {
    "incase_reference_webform" => { type: "webform", operators: %w[equals] },
    "incase_days_min" => { type: "number", operators: %w[equals greater_than less_than] },
    "incase_days_max" => { type: "number", operators: %w[equals greater_than less_than] },
    "client_email_contains" => { type: "string", operators: %w[contains] },
    "client_email_marketing_opt_in" => { type: "boolean", operators: %w[equals] }
  }.freeze

  FIELDS = FIELD_CONFIG.keys.freeze

  validates :field, :target, :operator, presence: true
  validate :field_allowed

  enum :target, { incase: "incase", client: "client" }, default: :incase, prefix: true

  acts_as_list scope: :campaign, column: :position

  before_validation :sync_target_with_field

  def display_value
    case field.to_s
    when "incase_reference_webform"
      Webform.unscoped.find_by(id: value.to_s.to_i)&.title || value.presence || "—"
    when "client_email_marketing_opt_in"
      I18n.t("campaigns.filter_fields.marketing_opt_in_value.#{ActiveModel::Type::Boolean.new.cast(value)}", default: value.to_s)
    else
      value.presence || "—"
    end
  end

  def self.client_field?(name)
    name.to_s.in?(CLIENT_FIELDS)
  end

  private

  def sync_target_with_field
    self.target = self.class.client_field?(field) ? :client : :incase
  end

  def field_allowed
    return if FIELDS.include?(field.to_s)

    errors.add(:field, :inclusion) unless new_record? && field.blank?
  end
end
