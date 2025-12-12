module AutomationRulesHelper
  def available_fields_for_event(event)
    return [] unless event.present?

    # Use the API endpoint to get fields
    # This will be called from JavaScript, so we'll cache it in a data attribute
    # For now, return the same structure as the API
    case event.to_s
    when /^incase\.(created|updated|status_changed)/
      [
        { key: "incase.status", label: "Статус заявки", type: "enum",
          values: ["new", "in_progress", "done", "canceled", "closed"] },
        { key: "incase.webform.kind", label: "Тип вебформы", type: "enum",
          values: ["order", "notify", "preorder", "abandoned_cart", "custom"] },
        { key: "client.email", label: "Email клиента", type: "string" },
        { key: "client.phone", label: "Телефон клиента", type: "string" },
        { key: "incase.items.count", label: "Количество товаров", type: "number" }
      ]
    when /^variant\.back_in_stock/
      [
        { key: "variant.quantity", label: "Количество товара", type: "number" },
        { key: "incase.webform.kind", label: "Тип вебформы", type: "enum",
          values: ["preorder", "notify"] },
        { key: "incase.status", label: "Статус заявки", type: "enum",
          values: ["new", "in_progress"] }
      ]
    else
      []
    end
  end

  def available_operators
    [
      { key: "equals", label: "равно" },
      { key: "not_equals", label: "не равно" },
      { key: "contains", label: "содержит" },
      { key: "present", label: "не пусто" },
      { key: "blank", label: "пусто" },
      { key: "greater_than", label: "больше" },
      { key: "less_than", label: "меньше" }
    ]
  end
end

