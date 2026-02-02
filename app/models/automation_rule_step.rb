# frozen_string_literal: true

class AutomationRuleStep < ApplicationRecord
  belongs_to :automation_rule
  has_many :automation_conditions, -> { ordered }, dependent: :destroy
  belongs_to :automation_action, optional: true
  belongs_to :message_template, optional: true
  belongs_to :next_step, class_name: "AutomationRuleStep", optional: true
  belongs_to :next_step_when_false, class_name: "AutomationRuleStep", optional: true

  acts_as_list scope: :automation_rule_id, column: :position

  enum :step_type, { condition: "condition", pause: "pause", action: "action" }

  validates :step_type, presence: true
  validate :step_type_specific_attributes

  scope :ordered, -> { order(:position, :id) }

  def summary
    case step_type
    when "condition"
      if automation_conditions.any?
        automation_conditions.map(&:summary_sentence).join("; ")
      else
        "Условие"
      end
    when "pause"
      delay_seconds.to_i.positive? ? format_pause_duration(delay_seconds.to_i) : "Пауза"
    when "action"
      if automation_action
        current_kind = automation_action.kind
        case current_kind
        when "send_email", "send_email_to_users", "send_sms_idgtl", "send_sms_moizvonki", "send_telegram"
          template = automation_rule.account.message_templates.find_by(id: automation_action.template_id)
          kind_label = I18n.t("automation_actions.kinds.#{automation_action.kind}")
          "#{kind_label}: #{template.title}"
        when "change_status"
          kind_label = I18n.t("automation_actions.kinds.#{automation_action.kind}")
          value_label = I18n.t("automation_conditions.values.incase_status.#{automation_action.value}")
          "#{kind_label}: #{value_label}"
        end
      else
        "Действие"
      end
    else
      step_type.humanize
    end
  end

  private

  def format_pause_duration(seconds)
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    parts = []
    parts << "#{hours} ч" if hours.positive?
    parts << "#{minutes} мин" if minutes.positive?
    parts.any? ? parts.join(" ") : "0 мин"
  end

  def step_type_specific_attributes
    case step_type
    when "condition"
      # Условия опциональны: шаг типа «условие» может иметь 0 или несколько условий
    when "pause"
      errors.add(:delay_seconds, "должна быть задана для шага паузы") if delay_seconds.nil? || delay_seconds.negative?
    when "action"
      errors.add(:base, "должно быть привязано действие или шаблон") unless automation_action_id.present? || message_template_id.present?
    end
  end
end
