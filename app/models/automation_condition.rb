class AutomationCondition < ApplicationRecord
  belongs_to :automation_rule, optional: true
  belongs_to :automation_rule_step, optional: true

  validates :field, :operator, presence: true
  validate :rule_or_step_present
  validate :operator_allowed_for_field
  validate :value_matches_input_type

  before_validation :set_automation_rule_from_step
  before_validation :reset_operator_and_value_if_field_changed

  scope :ordered, -> { order(:position, :id) }
  scope :for_rule, -> { where(automation_rule_step_id: nil) }
  scope :for_step, ->(step) { where(automation_rule_step_id: step.id) }

  def rule
    automation_rule_step&.automation_rule || automation_rule
  end

  # Краткое описание условия с переводами поля, оператора и значения (для summary шага)
  def summary_sentence
    helper = Object.new.extend(AutomationRulesHelper)
    [
      helper.field_label(field),
      helper.operator_label(operator),
      translated_value(helper)
    ].join(" ")
  end

  # Значение для отображения в списке (с переводом для boolean/enum)
  def display_value
    mapping = AutomationRulesHelper::FIELD_MAPPING[field]
    return value.presence || "—" if mapping.blank? || value.blank?

    case mapping[:type]
    when "boolean"
      I18n.t("automation_conditions.values.boolean.#{value}", default: value.to_s)
    when "enum"
      key = "automation_conditions.values.#{field&.gsub('.', '_')&.gsub('?', '')}.#{value}"
      I18n.t(key, default: value.to_s.humanize)
    else
      value.presence || "—"
    end
  end

  private

  def translated_value(helper)
    mapping = AutomationRulesHelper::FIELD_MAPPING[field]
    return value.to_s if mapping.blank? || value.blank?

    case mapping[:type]
    when "boolean"
      I18n.t("automation_conditions.values.boolean.#{value}", default: value.to_s)
    when "enum"
      key = "automation_conditions.values.#{field&.gsub('.', '_')&.gsub('?', '')}.#{value}"
      I18n.t(key, default: value.to_s.humanize)
    else
      value.to_s
    end
  end

  def rule_or_step_present
    return if automation_rule_id.present? || automation_rule_step_id.present?
    errors.add(:base, "должно быть указано правило или шаг")
  end

  def set_automation_rule_from_step
    return unless automation_rule_step_id.present? && automation_rule_id.blank?
    self.automation_rule_id = automation_rule_step&.automation_rule_id
  end
  
  def reset_operator_and_value_if_field_changed
    return unless field.present?
    
    # Используем единый маппинг полей
    field_mapping = AutomationRulesHelper::FIELD_MAPPING[field]
    return unless field_mapping
    
    helper = Object.new.extend(AutomationRulesHelper)
    
    # Всегда проверяем и устанавливаем оператор на основе поля
    available_ops = field_mapping[:operators]
    
    if available_ops.any?
      # Если оператор не подходит для текущего поля или не установлен, устанавливаем первый доступный
      unless operator.present? && available_ops.include?(operator)
        self.operator = available_ops.first
        
        # Устанавливаем значение на основе типа поля
        case field_mapping[:type]
        when 'boolean'
          self.value = ['true', 'false'].include?(value) ? value : 'false'
        when 'enum'
          if field_mapping[:values] && field_mapping[:values].include?(value)
            self.value = value
          elsif field_mapping[:values] && field_mapping[:values].any?
            self.value = field_mapping[:values].first
          else
            self.value = nil
          end
        when 'number'
          if value.present? && !value.to_s.match?(/^\d+$/)
            # Устанавливаем значение по умолчанию для числовых полей
            self.value = '0'
          elsif value.blank?
            # Если значение пустое, устанавливаем значение по умолчанию
            self.value = '0'
          end
        when 'string'
          # Для string оставляем как есть
        end
      end
    end
    
    # Если значение не подходит для текущего типа поля, устанавливаем первое допустимое
    if operator.present? && value.present?
      case field_mapping[:type]
      when 'boolean'
        unless ['true', 'false'].include?(value)
          self.value = 'false'
        end
      when 'enum'
        if field_mapping[:values] && !field_mapping[:values].include?(value)
          self.value = field_mapping[:values].first if field_mapping[:values].any?
        end
      when 'number'
        unless value.to_s.match?(/^\d+$/)
          # Устанавливаем значение по умолчанию для числовых полей
          self.value = '0'
        end
      end
    end
  end
  
  def operator_allowed_for_field
    return unless field.present? && operator.present?
    
    # Используем единый маппинг полей
    field_mapping = AutomationRulesHelper::FIELD_MAPPING[field]
    return unless field_mapping
    
    unless field_mapping[:operators].include?(operator)
      errors.add(:operator, "недоступен для поля #{field}")
    end
  end
  
  def value_matches_input_type
    return unless field.present? && operator.present?
    
    # Используем единый маппинг полей
    field_mapping = AutomationRulesHelper::FIELD_MAPPING[field]
    return unless field_mapping
    
    helper = Object.new.extend(AutomationRulesHelper)
    input_type = helper.input_type_for_condition({ type: field_mapping[:type] }, operator)
    
    # Значение обязательно
    if value.blank?
      errors.add(:value, "не может быть пустым")
      return
    end
    
    # Проверяем соответствие типа значения
    case input_type
    when 'select'
      if field_mapping[:type] == 'boolean'
        unless ['true', 'false'].include?(value)
          errors.add(:value, "должно быть true или false")
        end
      elsif field_mapping[:type] == 'enum'
        unless field_mapping[:values] && field_mapping[:values].include?(value)
          errors.add(:value, "должно быть одним из допустимых значений")
        end
      end
    when 'number'
      unless value.to_s.match?(/^\d+$/)
        errors.add(:value, "должно быть числом")
      end
    end
  end
  
end

