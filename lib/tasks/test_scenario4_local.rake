namespace :test do
  desc "Test Scenario 4 (Abandoned Cart) locally"
  task scenario4_local: :environment do
    account = Account.find_by(id: 2) || Account.first
    unless account
      puts "❌ Account not found"
      exit 1
    end

    rule = account.automation_rules.find_by(title: "Сценарий 4: Напоминание о брошенной корзине")
    unless rule
      puts "❌ Rule 'Сценарий 4: Напоминание о брошенной корзине' not found"
      exit 1
    end

    # Активируем правило для теста (сохраняем старое состояние)
    original_active = rule.active
    rule.update!(active: true)
    puts "ℹ️  Правило активировано для теста (было: #{original_active})"

    webform = account.webforms.find_by(kind: 'abandoned_cart')
    unless webform
      puts "❌ Webform with kind 'abandoned_cart' not found"
      exit 1
    end

    client = account.clients.first || account.clients.create!(name: "Test Client", email: "test@example.com")

    puts "=" * 80
    puts "ТЕСТ СЦЕНАРИЯ 4: БРОШЕННАЯ КОРЗИНА (ЛОКАЛЬНО)"
    puts "=" * 80
    puts ""
    puts "Аккаунт: ##{account.id} (#{account.name})"
    puts "Правило: ##{rule.id} (#{rule.title})"
    puts "Вебформа: ##{webform.id} (#{webform.kind})"
    puts "Клиент: ##{client.id} (#{client.name})"
    puts ""

    # Создаем тестовую заявку
    puts "-" * 80
    puts "СОЗДАНИЕ ТЕСТОВОЙ ЗАЯВКИ"
    puts "-" * 80
    
    # Удаляем старые тестовые заявки
    test_number = "TEST_SCENARIO4_#{Time.now.to_i}"
    account.incases.where(webform: webform, client: client).where("number LIKE ?", "TEST_SCENARIO4%").destroy_all

    incase = account.incases.create!(
      webform: webform,
      client: client,
      status: 'new',
      number: test_number
    )

    # Создаем тестовые товары и позиции
    product1 = account.products.first || account.products.create!(title: "Тестовый товар 1")
    variant1 = product1.variants.first || product1.variants.create!

    product2 = account.products.second || account.products.create!(title: "Тестовый товар 2")
    variant2 = product2.variants.first || product2.variants.create!

    incase.items.create!(variant: variant1, product: product1, quantity: 1, price: 100.0)
    incase.items.create!(variant: variant2, product: product2, quantity: 1, price: 200.0)

    puts "  Заявка ##{incase.id} создана"
    puts "  Позиций: #{incase.items.count}"
    puts ""

    # Сохраняем состояние до
    messages_before = account.automation_messages.where(incase: incase).count
    scheduled_before = rule.scheduled_for

    puts "-" * 80
    puts "СТРУКТУРА ПРАВИЛА ##{rule.id}"
    puts "-" * 80
    steps = rule.automation_rule_steps.ordered
    puts "  Всего шагов: #{steps.count}"
    steps.each_with_index do |step, idx|
      puts "  Шаг #{idx + 1} (##{step.id}): #{step.step_type}"
      if step.step_type == 'condition'
        step.automation_conditions.ordered.each do |cond|
          puts "    Условие: #{cond.field} #{cond.operator} #{cond.value}"
        end
        puts "    Следующий шаг (Да): ##{step.next_step_id}" if step.next_step_id
        puts "    Следующий шаг (Нет): ##{step.next_step_when_false_id}" if step.next_step_when_false_id
      elsif step.step_type == 'pause'
        puts "    Пауза: #{step.delay_seconds} секунд (#{step.delay_seconds / 60} минут)"
        puts "    Следующий шаг: ##{step.next_step_id}" if step.next_step_id
      elsif step.step_type == 'action'
        puts "    Действие: #{step.automation_action.kind} (#{step.automation_action.value})"
        puts "    Следующий шаг: ##{step.next_step_id}" if step.next_step_id
      end
    end
    puts ""

    # Запускаем автоматизацию
    puts "-" * 80
    puts "ЗАПУСК АВТОМАТИЗАЦИИ"
    puts "-" * 80
    puts "  Событие: incase.created"
    puts "  Объект: Incase ##{incase.id}"
    puts ""

    begin
      Automation::Engine.call(
        account: account,
        event: "incase.created",
        object: incase
      )
      puts "  ✅ Автоматизация запущена успешно"
    rescue => e
      puts "  ❌ Ошибка: #{e.message}"
      puts "  #{e.backtrace.first(5).join("\n  ")}"
      exit 1
    end
    puts ""

    # Проверяем результаты
    puts "-" * 80
    puts "РЕЗУЛЬТАТЫ ВЫПОЛНЕНИЯ"
    puts "-" * 80

    rule.reload
    incase.reload

    puts "  Статус заявки: #{incase.status}"
    puts "  Правило запланировано на: #{rule.scheduled_for || 'нет'}"
    if rule.scheduled_for
      time_until = (rule.scheduled_for - Time.zone.now).to_i
      if time_until > 0
        puts "  Время до выполнения: #{time_until} секунд (#{(time_until / 60.0).round(1)} минут)"
      else
        puts "  ⚠️  Должно было выполниться #{-time_until} секунд назад"
      end
    end
    puts ""

    messages_after = account.automation_messages.where(incase: incase).order(created_at: :desc)
    new_messages_count = messages_after.count - messages_before
    puts "  Сообщений создано: #{new_messages_count}"
    if new_messages_count > 0
      messages_after.limit(new_messages_count).each do |msg|
        puts "    Message ##{msg.id}:"
        puts "      Rule: ##{msg.automation_rule_id}"
        puts "      Action: #{msg.automation_action.kind}"
        puts "      Status: #{msg.status}"
        puts "      Created: #{msg.created_at}"
      end
    else
      puts "  ℹ️  Сообщений не создано (ожидается после паузы)"
    end
    puts ""

    # Проверяем условие
    puts "-" * 80
    puts "ПРОВЕРКА УСЛОВИЯ has_order_with_same_items?"
    puts "-" * 80
    result = incase.has_order_with_same_items?
    puts "  Результат: #{result}"
    order_webform = account.webforms.find_by(kind: 'order')
    if order_webform
      orders_count = incase.client.incases.where(webform: order_webform).count
      puts "  Заказов у клиента: #{orders_count}"
    end
    puts ""

    # Восстанавливаем состояние правила
    rule.update!(active: original_active) unless original_active

    puts "=" * 80
    puts "ТЕСТ ЗАВЕРШЕН"
    puts "=" * 80
    puts ""
    puts "Заявка ##{incase.id} создана для тестирования"
    puts "Для проверки после паузы выполните:"
    puts "  incase = Incase.find(#{incase.id})"
    puts "  rule = AutomationRule.find(#{rule.id})"
    puts "  # Проверьте rule.scheduled_for и выполните задачу вручную если нужно"
  end
end
