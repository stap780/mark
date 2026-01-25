namespace :automation do
  desc "Создать правила автоматизации для сценария Telegram → Email → done для аккаунта"
  task :create_telegram_email_fallback_rules, [:account_id] => :environment do |t, args|
    account_id = args[:account_id] || 2
    account = Account.find_by(id: account_id)
    
    unless account
      puts "❌ Аккаунт с id=#{account_id} не найден"
      exit 1
    end
    
    puts "📋 Создание правил автоматизации для аккаунта ##{account.id} (#{account.name})"
    puts ""
    
    ActiveRecord::Base.transaction do
      # Создаём шаблоны сообщений, если их нет
      telegram_subject = 'Создана заявка #{{incase.display_number}}'
      telegram_content = 'Здравствуйте, {{ client.name }}!

Создана заявка №{{ incase.display_number }} от {{ incase.created_at | date: "%d.%m.%Y" }}.

Спасибо за ваш заказ!'
      
      telegram_template = find_or_create_template(
        account: account,
        title: "Создана заявка (Telegram)",
        channel: "email", # MessageTemplate не имеет channel: telegram, используем email как базовый
        subject: telegram_subject,
        content: telegram_content
      )
      
      email_content = <<~HTML
        <!DOCTYPE html>
        <html>
          <body style="font-family: system-ui, -apple-system, sans-serif; font-size: 14px; color: #111827; margin: 0; padding: 24px;">
            <div style="max-width: 600px; margin: 0 auto; padding: 24px; background-color: #ffffff;">
              <h1 style="font-size: 20px; margin: 0 0 16px; color: #111827;">Создана заявка</h1>
              <p style="margin: 0 0 12px;">Здравствуйте, {{ client.name }}!</p>
              <p style="margin: 0 0 16px;">Создана заявка №{{ incase.display_number }} от {{ incase.created_at | date: '%d.%m.%Y' }}.</p>
              <p style="margin: 16px 0 0; font-size: 12px; color: #9ca3af;">С уважением,<br/>команда магазина.</p>
            </div>
          </body>
        </html>
      HTML
      
      email_subject = 'Создана заявка #{{incase.display_number}}'
      
      email_template = find_or_create_template(
        account: account,
        title: "Создана заявка (Email fallback)",
        channel: "email",
        subject: email_subject,
        content: email_content
      )
      
      puts "✅ Шаблоны сообщений созданы/найдены"
      puts "   - Telegram шаблон: ##{telegram_template.id} (#{telegram_template.title})"
      puts "   - Email шаблон: ##{email_template.id} (#{email_template.title})"
      puts ""
      
      # Правило A: Отправить Telegram при создании заявки
      rule_a = find_or_create_rule(
        account: account,
        title: "Отправить Telegram при создании заявки",
        event: "incase.created",
        condition_type: "simple",
        active: true,
        delay_seconds: 0
      )
      
      # Для правила A можно добавить условия, но для примера оставляем минимальное условие
      # которое всегда true (проверка наличия заявки)
      recreate_conditions(rule_a, [
        { field: "incase.status", operator: "equals", value: "new", position: 1 }
      ])
      
      recreate_actions(rule_a, [
        { kind: "send_telegram", value: telegram_template.id.to_s, position: 1 }
      ])
      
      puts "✅ Правило A создано: 'Отправить Telegram при создании заявки'"
      puts "   Событие: incase.created"
      puts "   Действие: send_telegram (шаблон ##{telegram_template.id})"
      puts ""
      
      # Правило B: Fallback на Email, если Telegram не доставился
      rule_b = find_or_create_rule(
        account: account,
        title: "Fallback на Email, если Telegram не доставился",
        event: "automation_message.failed",
        condition_type: "simple",
        active: true,
        delay_seconds: 0
      )
      
      recreate_conditions(rule_b, [
        { field: "automation_message.channel", operator: "equals", value: "telegram", position: 1 },
        { field: "client.email", operator: "contains", value: "@", position: 2 }
      ])
      
      recreate_actions(rule_b, [
        { kind: "send_email", value: email_template.id.to_s, position: 1 }
      ])
      
      puts "✅ Правило B создано: 'Fallback на Email, если Telegram не доставился'"
      puts "   Событие: automation_message.failed"
      puts "   Условия: automation_message.channel == 'telegram' AND client.email contains '@'"
      puts "   Действие: send_email (шаблон ##{email_template.id})"
      puts ""
      
      # Правило C: Сменить статус на done после успешной доставки
      rule_c = find_or_create_rule(
        account: account,
        title: "Сменить статус на done после успешной доставки",
        event: "automation_message.sent",
        condition_type: "simple",
        active: true,
        delay_seconds: 0
      )
      
      recreate_conditions(rule_c, [
        { field: "automation_message.incase.status", operator: "not_equals", value: "done", position: 1 }
      ])
      
      recreate_actions(rule_c, [
        { kind: "change_status", value: "done", position: 1 }
      ])
      
      puts "✅ Правило C создано: 'Сменить статус на done после успешной доставки'"
      puts "   Событие: automation_message.sent"
      puts "   Условия: automation_message.incase.status != 'done'"
      puts "   Действие: change_status('done')"
      puts ""
      
      puts "🎉 Все правила успешно созданы!"
      puts ""
      puts "📝 Следующие шаги:"
      puts "   1. Проверьте правила в UI: http://localhost:3000/accounts/#{account.id}/automation_rules"
      puts "   2. При необходимости отредактируйте условия или шаблоны"
      puts "   3. Создайте тестовую заявку для проверки работы"
    end
  end
  
  private
  
  def find_or_create_template(account:, title:, channel:, subject:, content:)
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
  
  def find_or_create_rule(account:, title:, event:, condition_type:, active:, delay_seconds:)
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
