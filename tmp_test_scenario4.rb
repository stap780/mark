# Тест Сценария 4: Брошенная корзина
account = Account.find(2)
incase = account.incases.find(2863)
rule = account.automation_rules.find(9) # Сценарий 4

puts "=" * 80
puts "ТЕСТ СЦЕНАРИЯ 4: БРОШЕННАЯ КОРЗИНА"
puts "=" * 80
puts ""

# Сохраняем текущее состояние
original_status = incase.status
messages_before = account.automation_messages.where(incase: incase).count
scheduled_before = rule.scheduled_for

puts "ТЕКУЩЕЕ СОСТОЯНИЕ:"
puts "  Заявка ##{incase.id}"
puts "  Статус: #{original_status}"
puts "  Сообщений до: #{messages_before}"
puts "  Правило запланировано на: #{scheduled_before || 'нет'}"
puts ""

# Шаг 1: Меняем статус на new
puts "-" * 80
puts "ШАГ 1: ИЗМЕНЕНИЕ СТАТУСА НА 'new'"
puts "-" * 80
incase.update!(status: 'new')
puts "  Статус изменен на: #{incase.status}"
puts ""

# Шаг 2: Проверяем структуру правила
puts "-" * 80
puts "ШАГ 2: СТРУКТУРА ПРАВИЛА ##{rule.id}"
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

# Шаг 3: Запускаем автоматизацию
puts "-" * 80
puts "ШАГ 3: ЗАПУСК АВТОМАТИЗАЦИИ"
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
  puts "  #{e.backtrace.first(3).join("\n  ")}"
end
puts ""

# Шаг 4: Проверяем результаты
puts "-" * 80
puts "ШАГ 4: РЕЗУЛЬТАТЫ ВЫПОЛНЕНИЯ"
puts "-" * 80

# Перезагружаем данные
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

# Проверяем сообщения
messages_after = account.automation_messages.where(incase: incase).order(created_at: :desc)
new_messages = messages_after.limit(messages_after.count - messages_before)
puts "  Сообщений создано: #{new_messages.count}"
if new_messages.any?
  new_messages.each do |msg|
    puts "    Message ##{msg.id}:"
    puts "      Rule: ##{msg.automation_rule_id}"
    puts "      Action: #{msg.automation_action.kind}"
    puts "      Status: #{msg.status}"
    puts "      Created: #{msg.created_at}"
  end
else
  puts "  ⚠️  Сообщений не создано (ожидается после паузы)"
end
puts ""

# Шаг 5: Проверяем условие has_order_with_same_items?
puts "-" * 80
puts "ШАГ 5: ПРОВЕРКА УСЛОВИЯ has_order_with_same_items?"
puts "-" * 80
result = incase.has_order_with_same_items?
puts "  Результат: #{result}"
puts "  Заказов у клиента: #{incase.client.incases.where(webform: account.webforms.find_by(kind: 'order')).count}"
puts ""

# Шаг 6: Имитируем выполнение после паузы (если нужно)
if rule.scheduled_for && rule.scheduled_for > Time.zone.now
  puts "-" * 80
  puts "ШАГ 6: ИНФОРМАЦИЯ О ПАУЗЕ"
  puts "-" * 80
  puts "  Автоматизация запланирована на #{rule.scheduled_for}"
  puts "  После паузы будет проверено условие has_order_with_same_items?"
  puts "  Если false → отправится email и статус станет 'done'"
  puts "  Если true → статус станет 'closed' (без email)"
  puts ""
  puts "  Для немедленного тестирования можно выполнить:"
  puts "    job = SolidQueue::ScheduledExecution.joins(:job).where(solid_queue_jobs: { active_job_id: '#{rule.active_job_id}' }).first"
  puts "    AutomationRuleExecutionJob.perform_now(account_id: #{account.id}, rule_id: #{rule.id}, resume_from_step_id: #{rule.automation_rule_steps.ordered.second.id}, context: {...})"
else
  puts "-" * 80
  puts "ШАГ 6: ПРОВЕРКА ФИНАЛЬНОГО СОСТОЯНИЯ"
  puts "-" * 80
  puts "  Статус заявки: #{incase.status}"
  puts "  Сообщений создано: #{messages_after.count - messages_before}"
end
puts ""

puts "=" * 80
puts "ТЕСТ ЗАВЕРШЕН"
puts "=" * 80
