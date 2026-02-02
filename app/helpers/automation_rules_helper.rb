module AutomationRulesHelper
  # Единый маппинг всех полей с их операторами и значениями
  FIELD_MAPPING = {
    "incase.status" => {
      type: "enum",
      operators: ["equals", "not_equals"],
      values: ["new", "in_progress", "done", "canceled", "closed"]
    },
    "incase.webform.kind" => {
      type: "enum",
      operators: ["equals", "not_equals"],
      values: ["order", "notify", "preorder", "abandoned_cart", "custom"]
    },
    "incase.webform.title" => {
      type: "string",
      operators: ["contains"],
      values: nil
    },
    "incase.has_order_with_same_items?" => {
      type: "boolean",
      operators: ["equals"],
      values: ["true", "false"]
    },
    "client.email" => {
      type: "string",
      operators: ["contains"],
      values: nil
    },
    "client.phone" => {
      type: "string",
      operators: ["contains"],
      values: nil
    },
    "incase.items.count" => {
      type: "number",
      operators: ["equals", "not_equals", "greater_than", "less_than"],
      values: nil
    },
    "variant.quantity" => {
      type: "number",
      operators: ["equals", "not_equals", "greater_than", "less_than"],
      values: nil
    },
    "automation_message.channel" => {
      type: "enum",
      operators: ["equals", "not_equals"],
      values: ["email", "telegram", "sms", "whatsapp"]
    },
    "automation_message.status" => {
      type: "enum",
      operators: ["equals", "not_equals"],
      values: ["pending", "sent", "failed", "delivered", "email_fbl", "email_unsubscribe", "email_open", "email_click"]
    },
    "automation_message.incase.status" => {
      type: "enum",
      operators: ["equals", "not_equals"],
      values: ["new", "in_progress", "done", "canceled", "closed"]
    },
    "automation_message.client.email" => {
      type: "string",
      operators: ["contains"],
      values: nil
    }
  }.freeze

  # Получить информацию о поле из маппинга
  def field_info_by_key(field_key)
    mapping = FIELD_MAPPING[field_key]
    return nil unless mapping

    {
      key: field_key,
      type: mapping[:type],
      operators: mapping[:operators],
      values: mapping[:values]
    }
  end

  def available_fields_for_event(event)
    return [] unless event.present?

    # Используем маппинг для получения полей
    case event.to_s
    when /^incase\.(created|updated)/
      fields = [
        field_info_by_key("incase.status"),
        field_info_by_key("incase.webform.kind"),
        field_info_by_key("incase.webform.title"),
        field_info_by_key("client.email"),
        field_info_by_key("client.phone"),
        field_info_by_key("incase.items.count"),
        field_info_by_key("incase.has_order_with_same_items?")
      ].compact.map do |field|
        {
          key: field[:key],
          label: field_label(field[:key]),
          type: field[:type],
          values: field[:values]
        }
      end
      
      fields
    when /^variant\.back_in_stock/
      [
        field_info_by_key("variant.quantity"),
        field_info_by_key("incase.webform.kind"),
        field_info_by_key("incase.status")
      ].compact.map do |field|
        {
          key: field[:key],
          label: field_label(field[:key]),
          type: field[:type],
          values: field[:values]
        }
      end
    when /^automation_message\.(sent|failed)/
      fields = [
        field_info_by_key("automation_message.channel"),
        field_info_by_key("automation_message.status"),
        field_info_by_key("automation_message.incase.status"),
        field_info_by_key("automation_message.client.email"),
        field_info_by_key("client.email"),
        field_info_by_key("client.phone")
      ].compact.map do |field|
        {
          key: field[:key],
          label: field_label(field[:key]),
          type: field[:type],
          values: field[:values]
        }
      end
      
      fields
    else
      []
    end
  end

  def field_label(field_key)
    {
      "incase.status" => "Статус заявки",
      "incase.webform.kind" => "Тип вебформы",
      "incase.webform.title" => "Название вебформы",
      "incase.has_order_with_same_items?" => "Есть заказ с такими же позициями",
      "client.email" => "Email клиента",
      "client.phone" => "Телефон клиента",
      "incase.items.count" => "Количество товаров",
      "variant.quantity" => "Количество товара",
      "automation_message.channel" => "Канал сообщения",
      "automation_message.status" => "Статус сообщения",
      "automation_message.incase.status" => "Статус заявки (через сообщение)",
      "automation_message.client.email" => "Email клиента (через сообщение)"
    }[field_key] || field_key.humanize
  end

  def available_operators
    [
      { key: "equals", label: "равно" },
      { key: "not_equals", label: "не равно" },
      { key: "contains", label: "содержит" },
      { key: "greater_than", label: "больше" },
      { key: "less_than", label: "меньше" }
    ]
  end

  # Определяет доступные операторы для поля
  def available_operators_for_field(field_info)
    return [] unless field_info
    
    # Используем маппинг напрямую по ключу поля
    field_key = field_info.is_a?(Hash) ? (field_info[:key] || field_info['key']) : nil
    if field_key
      mapping = FIELD_MAPPING[field_key]
      if mapping
        return mapping[:operators].map { |op| { key: op, label: operator_label(op) } }
      end
    end
    
    # Fallback на старую логику по типу (для обратной совместимости)
    case field_info[:type] || field_info['type']
    when 'boolean'
      [{ key: "equals", label: "равно" }]
    when 'enum'
      [
        { key: "equals", label: "равно" },
        { key: "not_equals", label: "не равно" }
      ]
    when 'string'
      [
        { key: "contains", label: "содержит" }
      ]
    when 'number'
      [
        { key: "equals", label: "равно" },
        { key: "not_equals", label: "не равно" },
        { key: "greater_than", label: "больше" },
        { key: "less_than", label: "меньше" }
      ]
    else
      available_operators
    end
  end

  def operator_label(operator_key)
    {
      "equals" => "равно",
      "not_equals" => "не равно",
      "contains" => "содержит",
      "greater_than" => "больше",
      "less_than" => "меньше"
    }[operator_key] || operator_key.humanize
  end

  # Определяет тип input для комбинации field + operator
  def input_type_for_condition(field_info, operator)
    return nil if operator.blank? || field_info.blank?
    
    case field_info[:type]
    when 'boolean'
      'select' # Всегда select для булевых полей
    when 'enum'
      'select' # Всегда select для enum полей
    when 'string'
      'text' # Текст для строковых полей
    when 'number'
      'number' # Число для числовых полей
    else
      'text' # По умолчанию текст
    end
  end

  # Возвращает опции для select
  def select_options_for_condition(field_info, operator)
    return [] unless field_info
    
    field_key = field_info[:key] || field_info['key']
    
    case field_info[:type]
    when 'boolean'
      [
        [I18n.t('automation_conditions.values.boolean.true'), "true"],
        [I18n.t('automation_conditions.values.boolean.false'), "false"]
      ]
    when 'enum'
      field_info[:values].map do |v|
        translation_key = "automation_conditions.values.#{field_key&.gsub('.', '_')&.gsub('?', '')}.#{v}"
        label = I18n.t(translation_key, default: v.humanize)
        [label, v]
      end
    else
      []
    end
  end

  # Проверяет, требует ли оператор значения
  # Все операторы требуют значения (операторы без значения удалены)
  def operator_requires_value?(operator)
    operator.present?
  end

  # Следующий шаг по позиции (для отображения цепочки, когда next_step не задан).
  # Не используем порядок, если шаг уже является целью ветки (next_step/next_step_when_false другого шага).
  def next_step_in_ordered(step, automation_rule)
    return nil if step_referenced_as_branch?(step, automation_rule)
    steps = automation_rule.automation_rule_steps.ordered.to_a
    idx = steps.index(step)
    idx && steps[idx + 1]
  end

  def step_referenced_as_branch?(step, automation_rule)
    automation_rule.automation_rule_steps.exists?(next_step_id: step.id) ||
      automation_rule.automation_rule_steps.exists?(next_step_when_false_id: step.id)
  end
end

