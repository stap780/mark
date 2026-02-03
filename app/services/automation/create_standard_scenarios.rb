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
        content: '<!DOCTYPE html>
<html>
  <body style="font-family: system-ui, -apple-system, BlinkMacSystemFont, \'Segoe UI\', sans-serif; font-size: 14px; color: #111827; margin: 0; padding: 0;">
    <div style="max-width: 600px; margin: 0 auto; padding: 24px; background-color: #ffffff;">
      <h1 style="font-size: 20px; margin: 0 0 16px; color: #111827;">Спасибо за ваш заказ</h1>

      <p style="margin: 0 0 12px;">Здравствуйте, {{ client.name }}!</p>
      <p style="margin: 0 0 16px;">Ваш заказ №{{ incase.display_number }} принят в обработку. Ниже список товаров:</p>

      <table style="width: 100%; border-collapse: collapse; margin-bottom: 16px;">
        <thead>
          <tr>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;">Товар</th>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;">Кол-во</th>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;">Сумма</th>
          </tr>
        </thead>
        <tbody>
          {% for item in incase.items %}
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;">{{ item.product_title }}</td>
              <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;">{{ item.quantity }}</td>
              <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;">{{ item.sum }}</td>
            </tr>
          {% endfor %}
        </tbody>
      </table>

      <p style="margin: 0 0 4px; font-size: 12px; color: #6b7280;">Мы свяжемся с вами для уточнения деталей заказа.</p>
      <p style="margin: 16px 0 0; font-size: 12px; color: #9ca3af;">С уважением,<br/>команда магазина.</p>
    </div>
  </body>
</html>'
      )

      rule = find_or_create_rule(
        title: "Сценарий 1: Отправка подтверждения заказа",
        event: "incase.created",
        active: false
      )

      create_chain(rule, {
        conditions: [
          { field: "incase.webform.kind", operator: "equals", value: "order" },
          { field: "incase.status", operator: "equals", value: "new" }
        ],
        delay_seconds: 0,
        actions: [
          { kind: "send_email", value: template.id.to_s },
          { kind: "change_status", value: "in_progress" }
        ]
      })
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
        content: '<!DOCTYPE html>
<html>
  <body style="font-family: system-ui, -apple-system, BlinkMacSystemFont, \'Segoe UI\', sans-serif; font-size: 14px; color: #111827; margin: 0; padding: 0;">
    <div style="max-width: 600px; margin: 0 auto; padding: 24px; background-color: #ffffff;">
      <h1 style="font-size: 20px; margin: 0 0 16px; color: #111827;">Спасибо за ваш предзаказ</h1>

      <p style="margin: 0 0 12px;">Здравствуйте, {{ client.name }}!</p>
      <p style="margin: 0 0 16px;">Ваш предзаказ №{{ incase.display_number }} принят. Мы уведомим вас, когда товар появится в наличии. Ниже список товаров:</p>

      <table style="width: 100%; border-collapse: collapse; margin-bottom: 16px;">
        <thead>
          <tr>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;">Товар</th>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;">Кол-во</th>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;">Сумма</th>
          </tr>
        </thead>
        <tbody>
          {% for item in incase.items %}
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;">{{ item.product_title }}</td>
              <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;">{{ item.quantity }}</td>
              <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;">{{ item.sum }}</td>
            </tr>
          {% endfor %}
        </tbody>
      </table>

      <p style="margin: 0 0 4px; font-size: 12px; color: #6b7280;">Мы свяжемся с вами для уточнения деталей заказа.</p>
      <p style="margin: 16px 0 0; font-size: 12px; color: #9ca3af;">С уважением,<br/>команда магазина.</p>
    </div>
  </body>
</html>'
      )

      rule = find_or_create_rule(
        title: "Сценарий 2: Отправка подтверждения предзаказа",
        event: "incase.created",
        active: false
      )

      create_chain(rule, {
        conditions: [
          { field: "incase.webform.kind", operator: "equals", value: "preorder" },
          { field: "incase.status", operator: "equals", value: "new" }
        ],
        delay_seconds: 0,
        actions: [
          { kind: "send_email", value: template.id.to_s },
          { kind: "change_status", value: "in_progress" }
        ]
      })
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
        subject: 'Товары появились в наличии!',
        content: '<!DOCTYPE html>
<html>
  <body style="font-family: system-ui, -apple-system, BlinkMacSystemFont, \'Segoe UI\', sans-serif; font-size: 14px; color: #111827; margin: 0; padding: 0;">
    <div style="max-width: 600px; margin: 0 auto; padding: 24px; background-color: #ffffff;">
      <h1 style="font-size: 20px; margin: 0 0 16px; color: #111827;">Товары появились в наличии</h1>

      <p style="margin: 0 0 12px;">Здравствуйте, {{ client.name }}!</p>
      <p style="margin: 0 0 16px;">Товары, на которые вы подписались, появились в наличии:</p>

      <table style="width: 100%; border-collapse: collapse; margin-bottom: 16px;">
        <thead>
          <tr>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;">Товар</th>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;"></th>
          </tr>
        </thead>
        <tbody>
          {% for incase in client.incases_for_notify %}
            {% for item in incase.items %}
              <tr>
                <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;">{{ item.product_title }}</td>
                <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;"><a href="{{ item.product_link }}" style="color: #2563eb; text-decoration: none;">подробнее</a></td>
              </tr>
            {% endfor %}
          {% endfor %}
        </tbody>
      </table>

      <p style="margin: 16px 0 0; font-size: 12px; color: #9ca3af;">С уважением,<br/>команда магазина.</p>
    </div>
  </body>
</html>'
      )

      rule = find_or_create_rule(
        title: "Сценарий 3: Уведомление о поступлении товара",
        event: "variant.back_in_stock",
        active: false
      )

      create_chain(rule, {
        conditions: [
          { field: "incase.webform.kind", operator: "equals", value: "notify" },
          { field: "variant.quantity", operator: "greater_than", value: "0" }
        ],
        delay_seconds: 0,
        actions: [
          { kind: "send_email", value: template.id.to_s },
          { kind: "change_status", value: "done" }
        ]
      })
    end

    # Сценарий 4: Брошенная корзина (с ветвлением Да/Нет)
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
        content: '<!DOCTYPE html>
<html>
  <body style="font-family: system-ui, -apple-system, BlinkMacSystemFont, \'Segoe UI\', sans-serif; font-size: 14px; color: #111827; margin: 0; padding: 0;">
    <div style="max-width: 600px; margin: 0 auto; padding: 24px; background-color: #ffffff;">
      <h1 style="font-size: 20px; margin: 0 0 16px; color: #111827;">Вы забыли о товарах в корзине</h1>

      <p style="margin: 0 0 12px;">Здравствуйте, {{ client.name }}!</p>
      <p style="margin: 0 0 16px;">Вы оставили товары в корзине. Вернитесь и завершите покупку! Ниже список товаров:</p>

      <table style="width: 100%; border-collapse: collapse; margin-bottom: 16px;">
        <thead>
          <tr>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;">Товар</th>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;">Кол-во</th>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;">Сумма</th>
          </tr>
        </thead>
        <tbody>
          {% for item in incase.items %}
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;">{{ item.product_title }}</td>
              <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;">{{ item.quantity }}</td>
              <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;">{{ item.sum }}</td>
            </tr>
          {% endfor %}
        </tbody>
      </table>

      <p style="margin: 0 0 4px; font-size: 12px; color: #6b7280;">Мы свяжемся с вами для уточнения деталей заказа.</p>
      <p style="margin: 16px 0 0; font-size: 12px; color: #9ca3af;">С уважением,<br/>команда магазина.</p>
    </div>
  </body>
</html>'
      )

      rule = find_or_create_rule(
        title: "Сценарий 4: Напоминание о брошенной корзине",
        event: "incase.created",
        active: false
      )

      # Удаляем старые шаги если есть
      rule.automation_rule_steps.destroy_all
      rule.automation_conditions.destroy_all
      
      # Удаляем только те actions, которые не используются (не имеют связанных messages)
      used_action_ids = AutomationMessage.where(automation_rule_id: rule.id).distinct.pluck(:automation_action_id).compact
      if used_action_ids.any?
        rule.automation_actions.where.not(id: used_action_ids).destroy_all
      else
        rule.automation_actions.destroy_all
      end

      position = 1

      # Шаг 1: Условие (фильтруем тип события - только abandoned_cart)
      condition_step_1 = rule.automation_rule_steps.create!(
        step_type: "condition",
        position: position
      )
      position += 1

      # Добавляем условие фильтрации по типу вебформы
      condition_step_1.automation_conditions.create!(
        field: "incase.webform.kind",
        operator: "equals",
        value: "abandoned_cart",
        position: 1
      )

      # Ветка "Да" (тип события подходит): пауза → второе условие
      pause_step = rule.automation_rule_steps.create!(
        step_type: "pause",
        delay_seconds: 1800, # 30 минут
        position: position
      )
      condition_step_1.update_column(:next_step_id, pause_step.id)
      position += 1

      # Шаг 2: Условие (проверяем появился ли заказ после паузы)
      condition_step_2 = rule.automation_rule_steps.create!(
        step_type: "condition",
        position: position
      )
      pause_step.update_column(:next_step_id, condition_step_2.id)
      position += 1

      # Добавляем условие проверки заказа
      condition_step_2.automation_conditions.create!(
        field: "incase.has_order_with_same_items?",
        operator: "equals",
        value: "false",
        position: 1
      )

      # Ветка "Да" (заказа нет): отправляем email → change_status done
      email_action = rule.automation_actions.create!(
        kind: "send_email",
        value: template.id.to_s,
        position: 1
      )
      email_action_step = rule.automation_rule_steps.create!(
        step_type: "action",
        automation_action_id: email_action.id,
        position: position
      )
      condition_step_2.update_column(:next_step_id, email_action_step.id)
      position += 1

      # Действие: изменить статус на done
      status_action = rule.automation_actions.create!(
        kind: "change_status",
        value: "done",
        position: 2
      )
      status_action_step = rule.automation_rule_steps.create!(
        step_type: "action",
        automation_action_id: status_action.id,
        position: position
      )
      email_action_step.update_column(:next_step_id, status_action_step.id)

      # Ветка "Нет" (заказ появился): закрываем заявку
      close_action = rule.automation_actions.create!(
        kind: "change_status",
        value: "closed",
        position: 3
      )
      close_action_step = rule.automation_rule_steps.create!(
        step_type: "action",
        automation_action_id: close_action.id,
        position: position + 1
      )
      condition_step_2.update_column(:next_step_when_false_id, close_action_step.id)
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
        content: '<!DOCTYPE html>
<html>
  <body style="font-family: system-ui, -apple-system, BlinkMacSystemFont, \'Segoe UI\', sans-serif; font-size: 14px; color: #111827; margin: 0; padding: 0;">
    <div style="max-width: 600px; margin: 0 auto; padding: 24px; background-color: #ffffff;">
      <h1 style="font-size: 20px; margin: 0 0 16px; color: #111827;">Специальное предложение для вас!</h1>

      <p style="margin: 0 0 12px;">Здравствуйте, {{ client.name }}!</p>
      <p style="margin: 0 0 16px;">У нас действует скидка на товары. Не упустите возможность!</p>

      <p style="margin: 0 0 4px; font-size: 12px; color: #6b7280;">Мы свяжемся с вами для уточнения деталей заказа.</p>
      <p style="margin: 16px 0 0; font-size: 12px; color: #9ca3af;">С уважением,<br/>команда магазина.</p>
    </div>
  </body>
</html>'
      )

      rule = find_or_create_rule(
        title: "Сценарий 5: Уведомление о скидке",
        event: "incase.created",
        active: false
      )

      create_chain(rule, {
        conditions: [
          { field: "incase.webform.title", operator: "contains", value: "скидк" }
        ],
        delay_seconds: 0,
        actions: [
          { kind: "send_email", value: template.id.to_s }
        ]
      })
    end

    # Создает цепочку шагов для правила
    # options: { conditions: [...], delay_seconds: 0, actions: [...] }
    def create_chain(rule, options)
      # Удаляем старые шаги если есть
      rule.automation_rule_steps.destroy_all
      rule.automation_conditions.destroy_all
      
      # Удаляем только те actions, которые не используются (не имеют связанных messages)
      used_action_ids = AutomationMessage.where(automation_rule_id: rule.id).distinct.pluck(:automation_action_id).compact
      if used_action_ids.any?
        rule.automation_actions.where.not(id: used_action_ids).destroy_all
      else
        rule.automation_actions.destroy_all
      end

      steps = []
      position = 1

      # Шаг 1: Условие (если есть)
      if options[:conditions]&.any?
        condition_step = rule.automation_rule_steps.create!(
          step_type: "condition",
          position: position
        )
        position += 1

        # Добавляем условия в шаг
        options[:conditions].each_with_index do |cond_data, idx|
          condition_step.automation_conditions.create!(
            field: cond_data[:field],
            operator: cond_data[:operator],
            value: cond_data[:value],
            position: idx + 1
          )
        end

        steps << condition_step
      end

      # Шаг 2: Пауза (если delay_seconds > 0)
      if options[:delay_seconds].to_i > 0
        pause_step = rule.automation_rule_steps.create!(
          step_type: "pause",
          delay_seconds: options[:delay_seconds].to_i,
          position: position
        )
        position += 1

        # Связываем предыдущий шаг с паузой
        if steps.last
          steps.last.update_column(:next_step_id, pause_step.id)
        end

        steps << pause_step
      end

      # Шаги 3+: Действия
      if options[:actions]&.any?
        options[:actions].each_with_index do |action_data, idx|
          # Создаем AutomationAction
          action = rule.automation_actions.create!(
            kind: action_data[:kind],
            value: action_data[:value],
            position: idx + 1
          )

          # Создаем шаг action
          action_step = rule.automation_rule_steps.create!(
            step_type: "action",
            automation_action_id: action.id,
            position: position
          )
          position += 1

          # Связываем с предыдущим шагом
          if steps.last
            steps.last.update_column(:next_step_id, action_step.id)
          end

          steps << action_step
        end
      end
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

    def find_or_create_rule(title:, event:, active:)
      # Ищем по title, так как он уникален для каждого сценария
      rule = account.automation_rules.find_by(title: title)
      
      if rule
        rule.update!(
          event: event,
          active: active
        )
      else
        max_position = account.automation_rules.maximum(:position) || 0
        rule = account.automation_rules.create!(
          title: title,
          event: event,
          active: active,
          position: max_position + 1
        )
      end
      
      rule
    end

  end
end
