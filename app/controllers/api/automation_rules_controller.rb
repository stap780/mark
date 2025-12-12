class Api::AutomationRulesController < ApplicationController
  def available_fields
    event = params[:event]

    fields = case event
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

    operators = [
      { key: "equals", label: "равно" },
      { key: "not_equals", label: "не равно" },
      { key: "contains", label: "содержит" },
      { key: "present", label: "не пусто" },
      { key: "blank", label: "пусто" },
      { key: "greater_than", label: "больше" },
      { key: "less_than", label: "меньше" }
    ]

    render json: { fields: fields, operators: operators }
  end
end

