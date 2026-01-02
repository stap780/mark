module Automation
  class CreateStandardScenarios
    def initialize(account)
      @account = account
    end

    def call
      ActiveRecord::Base.transaction do
        create_scenario_1_order
        create_scenario_2_preorder
        create_scenario_3_back_in_stock
        create_scenario_4_abandoned_cart
        create_scenario_5_discount
      end
    end

    private

    attr_reader :account

    # Сценарий 1: Поступил заказ
    def create_scenario_1_order
      webform = find_or_create_webform(
        title: "Сценарий 1: Заказ",
        kind: "order",
        status: "active"
      )

      template = find_or_create_template(
        title: "Сценарий 1: Подтверждение заказа",
        channel: "email",
        subject: 'Ваш заказ #{{incase.display_number}} принят',
        content: 'Здравствуйте, {{client.name}}! Ваш заказ #{{incase.display_number}} принят в обработку.'
      )

      rule = find_or_create_rule(
        title: "Сценарий 1: Отправка подтверждения заказа",
        event: "incase.created",
        condition_type: "simple",
        active: false,
        delay_seconds: 0
      )

      recreate_conditions(rule, [
        { field: "incase.webform.kind", operator: "equals", value: "order", position: 1 },
        { field: "incase.status", operator: "equals", value: "new", position: 2 }
      ])

      recreate_actions(rule, [
        { kind: "send_email", value: template.id.to_s, position: 1 },
        { kind: "change_status", value: "in_progress", position: 2 }
      ])
    end

    # Сценарий 2: Поступил предзаказ
    def create_scenario_2_preorder
      webform = find_or_create_webform(
        title: "Сценарий 2: Предзаказ",
        kind: "preorder",
        status: "active"
      )

      template = find_or_create_template(
        title: "Сценарий 2: Подтверждение предзаказа",
        channel: "email",
        subject: 'Ваш предзаказ #{{incase.display_number}} принят',
        content: 'Здравствуйте, {{client.name}}! Ваш предзаказ #{{incase.display_number}} принят. Мы уведомим вас, когда товар появится в наличии.'
      )

      rule = find_or_create_rule(
        title: "Сценарий 2: Отправка подтверждения предзаказа",
        event: "incase.created",
        condition_type: "simple",
        active: false,
        delay_seconds: 0
      )

      recreate_conditions(rule, [
        { field: "incase.webform.kind", operator: "equals", value: "preorder", position: 1 },
        { field: "incase.status", operator: "equals", value: "new", position: 2 }
      ])

      recreate_actions(rule, [
        { kind: "send_email", value: template.id.to_s, position: 1 },
        { kind: "change_status", value: "in_progress", position: 2 }
      ])
    end

    # Сценарий 3: Товар появился в наличии
    def create_scenario_3_back_in_stock
      webform = find_or_create_webform(
        title: "Сценарий 3: Сообщить о поступлении",
        kind: "notify",
        status: "active"
      )

      template = find_or_create_template(
        title: "Сценарий 3: Товар появился в наличии",
        channel: "email",
        subject: 'Товар {{product.title}} появился в наличии!',
        content: 'Здравствуйте, {{client.name}}! Товар {{product.title}} ({{variant.title}}), на который вы подписались, появился в наличии. Количество: {{variant.quantity}} шт.'
      )

      rule = find_or_create_rule(
        title: "Сценарий 3: Уведомление о поступлении товара",
        event: "variant.back_in_stock",
        condition_type: "simple",
        active: false,
        delay_seconds: 0
      )

      recreate_conditions(rule, [
        { field: "incase.webform.kind", operator: "equals", value: "notify", position: 1 },
        { field: "variant.quantity", operator: "greater_than", value: "0", position: 2 }
      ])

      recreate_actions(rule, [
        { kind: "send_email", value: template.id.to_s, position: 1 },
        { kind: "change_status", value: "done", position: 2 }
      ])
    end

    # Сценарий 4: Брошенная корзина
    def create_scenario_4_abandoned_cart
      webform = find_or_create_webform(
        title: "Сценарий 4: Брошенная корзина",
        kind: "abandoned_cart",
        status: "active"
      )

      template = find_or_create_template(
        title: "Сценарий 4: Напоминание о брошенной корзине",
        channel: "email",
        subject: "Вы забыли о товарах в корзине",
        content: 'Здравствуйте, {{client.name}}! Вы оставили товары в корзине. Вернитесь и завершите покупку!'
      )

      rule = find_or_create_rule(
        title: "Сценарий 4: Напоминание о брошенной корзине",
        event: "incase.created",
        condition_type: "simple",
        active: false,
        delay_seconds: 3600
      )

      recreate_conditions(rule, [
        { field: "incase.webform.kind", operator: "equals", value: "abandoned_cart", position: 1 },
        { field: "incase.has_order_with_same_items?", operator: "equals", value: "false", position: 2 }
      ])

      recreate_actions(rule, [
        { kind: "send_email", value: template.id.to_s, position: 1 },
        { kind: "change_status", value: "done", position: 2 }
      ])
    end

    # Сценарий 5: Кастомная заявка о скидке
    def create_scenario_5_discount
      webform = find_or_create_webform(
        title: "Сценарий 5: Сообщить о скидке",
        kind: "custom",
        status: "active"
      )

      template = find_or_create_template(
        title: "Сценарий 5: Уведомление о скидке",
        channel: "email",
        subject: "Специальное предложение для вас!",
        content: 'Здравствуйте, {{client.name}}! У нас действует скидка на товары. Не упустите возможность!'
      )

      rule = find_or_create_rule(
        title: "Сценарий 5: Уведомление о скидке",
        event: "incase.created",
        condition_type: "simple",
        active: false,
        delay_seconds: 0
      )

      recreate_conditions(rule, [
        { field: "incase.webform.title", operator: "contains", value: "скидк", position: 1 }
      ])

      recreate_actions(rule, [
        { kind: "send_email", value: template.id.to_s, position: 1 }
      ])
    end

    def find_or_create_webform(title:, kind:, status:)
      # Для singleton kinds (order, notify, preorder, abandoned_cart) ищем по kind
      # Для custom ищем по title
      if ['order', 'notify', 'preorder', 'abandoned_cart'].include?(kind)
        webform = account.webforms.find_by(kind: kind)
      else
        webform = account.webforms.find_by(title: title, kind: kind)
      end
      
      if webform
        webform.update!(title: title, status: status)
      else
        webform = account.webforms.create!(
          title: title,
          kind: kind,
          status: status,
          # Настройки триггеров по умолчанию
          trigger_type: Webform.default_trigger_type_for_kind(kind),
          show_delay: 0,
          show_once_per_session: true,
          target_devices: "desktop,mobile,tablet",
          show_times: 0
        )
      end
      
      webform
    end

    def find_or_create_template(title:, channel:, subject:, content:)
      template = account.message_templates.find_by(title: title, channel: channel)
      
      if template
        template.update!(subject: subject, content: content)
      else
        template = account.message_templates.create!(
          title: title,
          channel: channel,
          subject: subject,
          content: content
        )
      end
      
      template
    end

    def find_or_create_rule(title:, event:, condition_type:, active:, delay_seconds:)
      rule = account.automation_rules.find_by(title: title, event: event)
      
      if rule
        rule.update!(
          event: event,
          condition_type: condition_type,
          active: active,
          delay_seconds: delay_seconds,
          logic_operator: "AND"
        )
      else
        max_position = account.automation_rules.maximum(:position) || 0
        rule = account.automation_rules.create!(
          title: title,
          event: event,
          condition_type: condition_type,
          active: active,
          delay_seconds: delay_seconds,
          logic_operator: "AND",
          position: max_position + 1
        )
      end
      
      rule
    end

    def recreate_conditions(rule, conditions_data)
      rule.automation_conditions.destroy_all
      
      conditions_data.each do |cond_data|
        rule.automation_conditions.create!(
          field: cond_data[:field],
          operator: cond_data[:operator],
          value: cond_data[:value],
          position: cond_data[:position]
        )
      end
      
      # Сохраняем правило, чтобы обновился condition JSON через before_save callback
      rule.save!
    end

    def recreate_actions(rule, actions_data)
      rule.automation_actions.destroy_all
      
      actions_data.each do |action_data|
        rule.automation_actions.create!(
          kind: action_data[:kind],
          value: action_data[:value],
          position: action_data[:position]
        )
      end
    end
  end
end

