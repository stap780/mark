namespace :test do
  desc "Full test Scenario 4: Test both branches (with order -> closed, without order -> done)"
  task scenario4_full: :environment do
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

    webform_abandoned = account.webforms.find_by(kind: 'abandoned_cart')
    webform_order = account.webforms.find_by(kind: 'order')
    
    unless webform_abandoned
      puts "❌ Webform with kind 'abandoned_cart' not found"
      exit 1
    end
    
    unless webform_order
      puts "❌ Webform with kind 'order' not found"
      exit 1
    end

    # Активируем правило для теста
    original_active = rule.active
    rule.update!(active: true) unless original_active

    puts "=" * 80
    puts "ПОЛНЫЙ ТЕСТ СЦЕНАРИЯ 4: БРОШЕННАЯ КОРЗИНА"
    puts "=" * 80
    puts ""

    # ========================================================================
    # ТЕСТ 1: С ЗАКАЗОМ (должен стать closed)
    # ========================================================================
    puts "=" * 80
    puts "ТЕСТ 1: С ЗАКАЗОМ (ожидается статус 'closed')"
    puts "=" * 80
    puts ""

    # Находим или создаем клиента
    client1 = account.clients.find_by(email: 'panaet80@mail.ru')
    if client1
      puts "Найден клиент ##{client1.id}: #{client1.name} (#{client1.email})"
    else
      client1 = account.clients.create!(
        name: "Test Client 1",
        email: "panaet80@mail.ru"
      )
      puts "Создан клиент ##{client1.id}: #{client1.name} (#{client1.email})"
    end

    # Удаляем старые тестовые заявки
    test_number1 = "TEST_SC4_WITH_ORDER_#{Time.now.to_i}"
    account.incases.where(webform: webform_abandoned, client: client1)
           .where("number LIKE ?", "TEST_SC4_WITH_ORDER%").destroy_all
    account.incases.where(webform: webform_order, client: client1)
           .where("number LIKE ?", "TEST_SC4_WITH_ORDER%").destroy_all

    # Создаем тестовые товары и варианты
    product1 = account.products.first || account.products.create!(title: "Тестовый товар 1")
    variant1 = product1.variants.first || product1.variants.create!

    product2 = account.products.second || account.products.create!(title: "Тестовый товар 2")
    variant2 = product2.variants.first || product2.variants.create!

    # Создаем заявку брошенной корзины
    incase1 = account.incases.create!(
      webform: webform_abandoned,
      client: client1,
      status: 'new',
      number: test_number1
    )

    incase1.items.create!(variant: variant1, product: product1, quantity: 1, price: 100.0)
    incase1.items.create!(variant: variant2, product: product2, quantity: 1, price: 200.0)

    puts "  Заявка брошенной корзины ##{incase1.id} создана"
    puts "  Позиций: #{incase1.items.count}"
    puts ""

    # Создаем заказ с теми же позициями
    order1 = account.incases.create!(
      webform: webform_order,
      client: client1,
      status: 'new',
      number: "#{test_number1}_ORDER"
    )

    order1.items.create!(variant: variant1, product: product1, quantity: 1, price: 100.0)
    order1.items.create!(variant: variant2, product: product2, quantity: 1, price: 200.0)

    puts "  Заказ ##{order1.id} создан с теми же позициями"
    puts "  Позиций: #{order1.items.count}"
    puts ""

    # Проверяем условие
    cart_items_hash = incase1.items.group_by { |i| i.variant_id }.transform_values { |items| items.sum(&:quantity) }
    order_items_hash = order1.items.group_by { |i| i.variant_id }.transform_values { |items| items.sum(&:quantity) }
    matches = cart_items_hash == order_items_hash
    puts "  Позиции совпадают: #{matches ? '✅ ДА' : '❌ НЕТ'}"
    puts "  Корзина: #{cart_items_hash.inspect}"
    puts "  Заказ: #{order_items_hash.inspect}"
    puts ""

    # Запускаем автоматизацию
    messages_before1 = account.automation_messages.where(incase: incase1).count
    puts "  Запуск автоматизации..."
    Automation::Engine.call(
      account: account,
      event: "incase.created",
      object: incase1
    )

    rule.reload
    incase1.reload

    puts "  Статус заявки: #{incase1.status}"
    puts "  Правило запланировано на: #{rule.scheduled_for || 'нет'}"
    puts ""

    # Ждем выполнения (если пауза небольшая, можно подождать)
    pause_step = rule.automation_rule_steps.find_by(step_type: 'pause')
    if pause_step && pause_step.delay_seconds <= 120
      puts "  ⏳ Пауза #{pause_step.delay_seconds} сек (#{(pause_step.delay_seconds / 60.0).round(1)} мин), ждем выполнения..."
      sleep(pause_step.delay_seconds + 5)
      rule.reload
      incase1.reload
      puts "  Статус после паузы: #{incase1.status}"
    else
      puts "  ⏳ Пауза #{pause_step ? pause_step.delay_seconds : 'неизвестно'} сек - слишком долго для ожидания в тесте"
      puts "  Проверьте результат позже вручную"
    end

    messages_after1 = account.automation_messages.where(incase: incase1).order(created_at: :desc)
    puts "  Сообщений создано: #{messages_after1.count - messages_before1}"
    if messages_after1.count > messages_before1
      messages_after1.limit(messages_after1.count - messages_before1).each do |msg|
        puts "    Message ##{msg.id}: #{msg.automation_action.kind}, Status: #{msg.status}"
      end
    end
    puts ""

    result1 = incase1.has_order_with_same_items?
    puts "  has_order_with_same_items?: #{result1}"
    puts ""

    if incase1.status == 'closed'
      puts "  ✅ ТЕСТ 1 ПРОЙДЕН: Статус 'closed' (заказ найден)"
    else
      puts "  ❌ ТЕСТ 1 НЕ ПРОЙДЕН: Ожидался статус 'closed', получен '#{incase1.status}'"
    end
    puts ""

    # ========================================================================
    # ТЕСТ 2: БЕЗ ЗАКАЗА (должен стать done)
    # ========================================================================
    puts "=" * 80
    puts "ТЕСТ 2: БЕЗ ЗАКАЗА (ожидается статус 'done')"
    puts "=" * 80
    puts ""

    # Находим или создаем клиента
    client2 = account.clients.find_by(email: 'panaet80@gmail.com')
    if client2
      puts "Найден клиент ##{client2.id}: #{client2.name} (#{client2.email})"
    else
      client2 = account.clients.create!(
        name: "Test Client 2",
        email: "panaet80@gmail.com"
      )
      puts "Создан клиент ##{client2.id}: #{client2.name} (#{client2.email})"
    end

    # Удаляем старые тестовые заявки
    test_number2 = "TEST_SC4_NO_ORDER_#{Time.now.to_i}"
    account.incases.where(webform: webform_abandoned, client: client2)
           .where("number LIKE ?", "TEST_SC4_NO_ORDER%").destroy_all

    # Создаем заявку брошенной корзины БЕЗ заказа
    incase2 = account.incases.create!(
      webform: webform_abandoned,
      client: client2,
      status: 'new',
      number: test_number2
    )

    incase2.items.create!(variant: variant1, product: product1, quantity: 1, price: 100.0)
    incase2.items.create!(variant: variant2, product: product2, quantity: 1, price: 200.0)

    puts "  Заявка брошенной корзины ##{incase2.id} создана"
    puts "  Позиций: #{incase2.items.count}"
    puts ""

    # Проверяем, что заказов нет
    orders_count = client2.incases.where(webform: webform_order).count
    puts "  Заказов у клиента: #{orders_count}"
    puts ""

    # Запускаем автоматизацию
    messages_before2 = account.automation_messages.where(incase: incase2).count
    puts "  Запуск автоматизации..."
    Automation::Engine.call(
      account: account,
      event: "incase.created",
      object: incase2
    )

    rule.reload
    incase2.reload

    puts "  Статус заявки: #{incase2.status}"
    puts "  Правило запланировано на: #{rule.scheduled_for || 'нет'}"
    puts ""

    # Ждем выполнения (если пауза небольшая)
    if pause_step && pause_step.delay_seconds <= 120
      puts "  ⏳ Пауза #{pause_step.delay_seconds} сек (#{(pause_step.delay_seconds / 60.0).round(1)} мин), ждем выполнения..."
      sleep(pause_step.delay_seconds + 5)
      rule.reload
      incase2.reload
      puts "  Статус после паузы: #{incase2.status}"
    else
      puts "  ⏳ Пауза #{pause_step ? pause_step.delay_seconds : 'неизвестно'} сек - слишком долго для ожидания в тесте"
      puts "  Проверьте результат позже вручную"
    end

    messages_after2 = account.automation_messages.where(incase: incase2).order(created_at: :desc)
    puts "  Сообщений создано: #{messages_after2.count - messages_before2}"
    if messages_after2.count > messages_before2
      messages_after2.limit(messages_after2.count - messages_before2).each do |msg|
        puts "    Message ##{msg.id}: #{msg.automation_action.kind}, Status: #{msg.status}"
      end
    end
    puts ""

    result2 = incase2.has_order_with_same_items?
    puts "  has_order_with_same_items?: #{result2}"
    puts ""

    if incase2.status == 'done'
      puts "  ✅ ТЕСТ 2 ПРОЙДЕН: Статус 'done' (email отправлен, заказа нет)"
    else
      puts "  ❌ ТЕСТ 2 НЕ ПРОЙДЕН: Ожидался статус 'done', получен '#{incase2.status}'"
    end
    puts ""

    # Восстанавливаем состояние правила
    rule.update!(active: original_active) unless original_active

    # ========================================================================
    # ИТОГИ
    # ========================================================================
    puts "=" * 80
    puts "ИТОГИ ТЕСТИРОВАНИЯ"
    puts "=" * 80
    puts ""
    puts "Тест 1 (с заказом):"
    puts "  Заявка ##{incase1.id}, Статус: #{incase1.status}, Ожидалось: closed"
    puts "  Результат: #{incase1.status == 'closed' ? '✅ ПРОЙДЕН' : '❌ НЕ ПРОЙДЕН'}"
    puts ""
    puts "Тест 2 (без заказа):"
    puts "  Заявка ##{incase2.id}, Статус: #{incase2.status}, Ожидалось: done"
    puts "  Результат: #{incase2.status == 'done' ? '✅ ПРОЙДЕН' : '❌ НЕ ПРОЙДЕН'}"
    puts ""
    puts "=" * 80
  end
end
