module AutomationRulesHelper
  # Единый маппинг всех полей с их операторами и значениями
  FIELD_MAPPING = {
    "incase.status" => {
      type: "enum",
      operators: ["equals", "not_equals"],
      values: nil  # dynamic: from account.incase_statuses
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
      values: nil  # dynamic: from account.incase_statuses
    },
    "automation_message.client.email" => {
      type: "string",
      operators: ["contains"],
      values: nil
    }
  }.freeze

  # Получить информацию о поле из маппинга
  def field_info_by_key(field_key, account: nil)
    mapping = FIELD_MAPPING[field_key]
    return nil unless mapping

    values = mapping[:values]
    if values.nil? && account && field_key.in?(["incase.status", "automation_message.incase.status"])
      values = account.incase_statuses.ordered.map { |s| [s.name, s.key] }
    end

    {
      key: field_key,
      type: mapping[:type],
      operators: mapping[:operators],
      values: values
    }
  end

  def available_fields_for_event(event, account: nil)
    return [] unless event.present?

    # Используем маппинг для получения полей
    case event.to_s
    when /^incase\.(created|updated)/
      fields = [
        field_info_by_key("incase.status", account: account),
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
        field_info_by_key("incase.status", account: account)
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
        field_info_by_key("automation_message.incase.status", account: account),
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
      vals = field_info[:values]
      return [] if vals.blank?
      # values может быть [[label, key], ...] (динамические из account) или ["new", "in_progress", ...] (статические)
      if vals.first.is_a?(Array)
        vals
      else
        vals.map do |v|
          translation_key = "automation_conditions.values.#{field_key&.gsub('.', '_')&.gsub('?', '')}.#{v}"
          label = I18n.t(translation_key, default: v.humanize)
          [label, v]
        end
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

  # Раскладка canvas: позиции блоков, пустых слотов и связи для линий.
  # Возвращает { positions:, slot_positions:, connections:, canvas_size:, block_w:, block_h: }
  def canvas_layout(automation_rule, _account)
    positions = {}
    slot_positions = {} # { parent_id => { "false" => {x,y}, "true" => {x,y} } } или для линейного { parent_id => { nil => {x,y} } }
    branch_labels = {} # { step_id => { "false" => {x,y}, "true" => {x,y} } } — позиции подписей Да/Нет
    condition_add_buttons = {} # { step_id => { "false" => {x,y}, "true" => {x,y} } } — кнопки + при условии
    connections = []
    block_w = 350
    block_h = 100
    gap_x = 48
    gap_y = 36

    root = automation_rule.automation_rule_steps.ordered.first
    if root
      next_proc = ->(s, ar) { next_step_in_ordered(s, ar) }
      canvas_layout_place_step(root, automation_rule, gap_x, gap_y, positions, slot_positions, branch_labels, condition_add_buttons, connections, block_w, block_h, gap_x, gap_y, next_proc)
    else
      cw = block_w + gap_x * 2
      ch = block_h + gap_y * 2
      slot_positions[:root] = { nil => { x: (cw / 2) - 20, y: (ch / 2) - 20 } }
    end

    if positions.any?
      max_x = positions.values.map { |p| p[:x] + block_w }.max + gap_x
      max_y = positions.values.map { |p| p[:y] + block_h }.max + gap_y
    else
      max_x = block_w + gap_x * 2
      max_y = block_h + gap_y * 2
    end
    canvas_w = max_x
    canvas_h = max_y

    { positions: positions, slot_positions: slot_positions, branch_labels: branch_labels, condition_add_buttons: condition_add_buttons, connections: connections, canvas_size: { w: canvas_w, h: canvas_h }, block_w: block_w, block_h: block_h }
  end

  private

  def canvas_layout_place_step(step, automation_rule, x, y, positions, slot_positions, branch_labels, condition_add_buttons, connections, block_w, block_h, gap_x, gap_y, next_proc)
    if step
      # Используем сохранённую позицию при перетаскивании, иначе вычисленную
      pos_x = step.canvas_x.present? ? step.canvas_x : x
      pos_y = step.canvas_y.present? ? step.canvas_y : y
      positions[step.id] = { x: pos_x, y: pos_y }
    end

    if step&.condition?
      no_step = step.next_step_when_false
      yes_step = step.next_step
      slot_x_no = x
      slot_y_no = y + block_h + gap_y
      slot_y_yes = y + block_h + gap_y

      no_result = canvas_layout_place_step(no_step, automation_rule, slot_x_no, slot_y_no, positions, slot_positions, branch_labels, condition_add_buttons, connections, block_w, block_h, gap_x, gap_y, next_proc)
      slot_x_yes = x + (block_w + gap_x) + no_result[:width]
      slot_positions[step.id] ||= {}
      slot_positions[step.id]["false"] = { x: slot_x_no + (block_w / 2) - 20, y: slot_y_no + 8 } unless no_step
      slot_positions[step.id]["true"] = { x: slot_x_yes + (block_w / 2) - 20, y: slot_y_yes + 8 } unless yes_step

      # Подписи Да/Нет между блоком условия и ветками
      label_y = y + block_h + (gap_y / 2) - 8
      branch_labels[step.id] = {
        "false" => { x: slot_x_no + (block_w / 2) - 12, y: label_y },
        "true" => { x: slot_x_yes + (block_w / 2) - 8, y: label_y }
      }

      # Кнопки + при условии — слева и справа в углах родительского блока
      condition_add_buttons[step.id] = {
        "false" => { x: x + 4, y: y + block_h + 4 },
        "true" => { x: x + block_w - 44, y: y + block_h + 4 }
      }

      yes_result = canvas_layout_place_step(yes_step, automation_rule, slot_x_yes, slot_y_yes, positions, slot_positions, branch_labels, condition_add_buttons, connections, block_w, block_h, gap_x, gap_y, next_proc)

      connections << { from: step.id, to: no_step.id, branch: "false" } if no_step
      connections << { from: step.id, to: yes_step.id, branch: "true" } if yes_step

      { width: no_result[:width] + (block_w + gap_x) + yes_result[:width] }
    elsif step
      next_step = step.next_step || next_proc.call(step, automation_rule)
      slot_x = x
      slot_y = y + block_h + gap_y
      if next_step
        connections << { from: step.id, to: next_step.id, branch: nil }
        canvas_layout_place_step(next_step, automation_rule, slot_x, slot_y, positions, slot_positions, branch_labels, condition_add_buttons, connections, block_w, block_h, gap_x, gap_y, next_proc)
      else
        slot_positions[step.id] ||= {}
        slot_positions[step.id][nil] = { x: slot_x + (block_w / 2) - 20, y: slot_y + 8 }  # по центру под блоком
      end
      { width: block_w + gap_x }
    else
      { width: 0 }
    end
  end
end

