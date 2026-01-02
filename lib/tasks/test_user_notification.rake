namespace :test do
  desc "Test sending emails to account users"
  task user_notification: :environment do
    # Находим пользователя и аккаунт
    user = User.find_by(email_address: 'admin2@example.com')
    unless user
      puts "❌ User admin2@example.com not found"
      exit 1
    end

    account = user.accounts.first
    unless account
      puts "❌ No account found for user admin2@example.com"
      exit 1
    end

    puts "=== Testing User Notification ==="
    puts "Account: #{account.name} (ID: #{account.id})"
    puts "Users in account: #{account.users.count}"
    account.users.each do |u|
      puts "  - #{u.email_address} (ID: #{u.id})"
    end
    puts ""

    # Переключаемся на аккаунт
    Account.switch_to(account.id)

    # Создаем или находим шаблон для пользователей (используем верстку как в письме для клиента)
    template_subject = 'Новый заказ №{{ incase.id }}'
    template_content = <<~'HTML'
      <!DOCTYPE html>
      <html>
        <body style="font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; font-size: 14px; color: #111827; margin: 0; padding: 0;">
          <div style="max-width: 600px; margin: 0 auto; padding: 24px; background-color: #ffffff;">
            <h1 style="font-size: 20px; margin: 0 0 16px; color: #111827;">Поступил новый заказ</h1>

            <p style="margin: 0 0 12px;">Заказ №{{ incase.id }} от <strong>{{ client.name }}</strong> ({{ client.email }}).</p>
            <p style="margin: 0 0 16px;">Ниже список товаров:</p>

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

            <p style="margin: 16px 0 0; font-size: 12px; color: #9ca3af;">С уважением,<br/>система автоматизации.</p>
          </div>
        </body>
      </html>
    HTML
    
    template = account.message_templates.find_or_create_by(
      title: "Тест: Уведомление о новом заказе (пользователям)",
      channel: "email"
    ) do |t|
      t.subject = template_subject
      t.content = template_content
    end
    
    # Обновляем шаблон, если он уже существовал
    template.update!(
      subject: template_subject,
      content: template_content
    )

    puts "Template: #{template.title} (ID: #{template.id})"
    puts ""

    # Создаем или находим правило автоматизации
    rule = account.automation_rules.find_by(
      title: "Тест: Уведомление пользователям о заказе",
      event: "incase.created"
    )
    
    unless rule
      max_position = account.automation_rules.maximum(:position) || 0
      rule = account.automation_rules.create!(
        title: "Тест: Уведомление пользователям о заказе",
        event: "incase.created",
        condition_type: "simple",
        active: true,
        delay_seconds: 0,
        logic_operator: "AND",
        position: max_position + 1
      )
      
      # Создаем условие сразу после создания правила
      rule.automation_conditions.create!(
        field: "incase.webform.kind",
        operator: "equals",
        value: "order",
        position: 1
      )
      
      # Сохраняем правило, чтобы обновился condition JSON
      rule.save!
    else
      # Обновляем существующее правило в транзакции
      ActiveRecord::Base.transaction do
        # Сначала создаем новое условие
        rule.automation_conditions.destroy_all
        rule.automation_conditions.create!(
          field: "incase.webform.kind",
          operator: "equals",
          value: "order",
          position: 1
        )
        
        # Затем обновляем правило
        rule.update!(
          active: true,
          condition_type: "simple",
          delay_seconds: 0
        )
      end
    end

    # Создаем действие для отправки пользователям
    action = rule.automation_actions.find_or_create_by(
      kind: "send_email_to_users"
    ) do |a|
      a.value = template.id.to_s
      a.position = 1
    end
    action.update!(value: template.id.to_s)

    puts "Rule: #{rule.title} (ID: #{rule.id})"
    puts "Action: #{action.kind} (Template ID: #{action.template_id})"
    puts "Active: #{rule.active}"
    puts ""

    # Находим или создаем вебформу типа order
    webform = account.webforms.find_or_create_by(kind: "order") do |w|
      w.title = "Тестовая форма заказа"
      w.status = "active"
    end

    # Находим или создаем клиента для теста
    client = account.clients.first_or_create!(
      name: "Тестовый клиент",
      email: "test@example.com"
    )

    puts "Webform: #{webform.title} (ID: #{webform.id})"
    puts "Client: #{client.name} (ID: #{client.id})"
    puts ""

    # Создаем тестовую заявку
    incase = account.incases.create!(
      webform: webform,
      client: client,
      status: "new",
      custom_fields: {}
    )

    puts "Created test incase ##{incase.id} (display_number: #{incase.display_number})"
    puts ""

    # Создаем тестовые товары и позиции
    product1 = account.products.find_or_create_by!(title: "Тестовый товар 1")
    variant1 = product1.variants.first || product1.variants.create!

    product2 = account.products.find_or_create_by!(title: "Тестовый товар 2")
    variant2 = product2.variants.first || product2.variants.create!

    # Создаем позиции в заявке
    incase.items.create!(
      product: product1,
      variant: variant1,
      quantity: 2,
      price: 100.0
    )

    incase.items.create!(
      product: product2,
      variant: variant2,
      quantity: 1,
      price: 300.0
    )

    puts "Created items:"
    incase.items.each do |item|
      puts "  - #{item.product.title} (×#{item.quantity}) - #{item.sum}₽"
    end
    puts ""

    # Вызываем автоматизацию вручную (как в API контроллере)
    Automation::Engine.call(
      account: account,
      event: "incase.created",
      object: incase
    )

    puts "Triggered automation engine"
    puts ""

    # Ждем немного, чтобы дать время на обработку
    sleep 2

    # Проверяем результаты
    messages = account.automation_messages
                      .where(automation_rule: rule, automation_action: action)
                      .where.not(user_id: nil)
                      .order(created_at: :desc)

    puts "=== Results ==="
    puts "Total messages created: #{messages.count}"
    puts ""

    if messages.any?
      messages.each do |msg|
        puts "Message ID: #{msg.id}"
        puts "  User: #{msg.user&.email_address}"
        puts "  Status: #{msg.status}"
        puts "  Subject: #{msg.subject}"
        puts "  Created: #{msg.created_at}"
        puts "  Sent: #{msg.sent_at || 'N/A'}"
        if msg.error_message
          puts "  Error: #{msg.error_message}"
        end
        puts "  Content preview: #{msg.content[0..100]}..."
        puts "---"
      end

      sent_count = messages.where(status: 'sent').count
      failed_count = messages.where(status: 'failed').count
      pending_count = messages.where(status: 'pending').count

      puts ""
      puts "Summary:"
      puts "  ✅ Sent: #{sent_count}"
      puts "  ❌ Failed: #{failed_count}"
      puts "  ⏳ Pending: #{pending_count}"

      if sent_count > 0
        puts ""
        puts "✅ SUCCESS! Emails were sent to users!"
      elsif failed_count > 0
        puts ""
        puts "❌ FAILED! Some emails failed to send. Check error messages above."
      end
    else
      puts "❌ No messages created. Automation rule may not have executed."
      puts "Check if rule is active and conditions are met."
    end
  end
end

