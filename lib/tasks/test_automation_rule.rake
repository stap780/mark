namespace :test do
  desc "Test automation rule execution"
  task automation_rule: :environment do
    account_id = ENV['ACCOUNT_ID']&.to_i || 2
    rule_id = ENV['RULE_ID']&.to_i
    incase_id = ENV['INCASE_ID']&.to_i
    variant_id = ENV['VARIANT_ID']&.to_i
    message_id = ENV['MESSAGE_ID']&.to_i
    
    unless rule_id
      puts "Usage:"
      puts "  ACCOUNT_ID=2 RULE_ID=5 INCASE_ID=123 rake test:automation_rule"
      puts "  ACCOUNT_ID=2 RULE_ID=5 VARIANT_ID=456 rake test:automation_rule"
      puts "  ACCOUNT_ID=2 RULE_ID=5 MESSAGE_ID=789 rake test:automation_rule"
      exit 1
    end
    
    Account.switch_to(account_id)
    account = Account.find(account_id)
    rule = account.automation_rules.find_by(id: rule_id)
    
    unless rule
      puts "❌ Rule ##{rule_id} not found"
      exit 1
    end
    
    puts "=== Testing Automation Rule ==="
    puts "Rule ID: #{rule.id}"
    puts "Title: #{rule.title}"
    puts "Event: #{rule.event}"
    puts "Active: #{rule.active? ? '✅' : '❌'}"
    puts ""
    
    # Показываем структуру шагов
    puts "--- Rule Steps Chain ---"
    steps = rule.automation_rule_steps.ordered
    if steps.any?
      steps.each_with_index do |step, idx|
        puts "Step ##{idx + 1} (ID: #{step.id}, Position: #{step.position}):"
        puts "  Type: #{step.step_type}"
        puts "  Summary: #{step.summary}"
        
        if step.step_type == 'condition'
          step.automation_conditions.ordered.each do |cond|
            puts "    Condition: #{cond.field} #{cond.operator} #{cond.value}"
          end
          puts "    Next step (Да): #{step.next_step_id || 'нет'}"
          puts "    Next step (Нет): #{step.next_step_when_false_id || 'нет'}"
        elsif step.step_type == 'pause'
          hours = step.delay_seconds.to_i / 3600
          minutes = (step.delay_seconds.to_i % 3600) / 60
          puts "    Delay: #{hours}ч #{minutes}мин"
          puts "    Next step: #{step.next_step_id || 'нет'}"
        elsif step.step_type == 'action'
          puts "    Next step: #{step.next_step_id || 'нет'}"
        end
        puts ""
      end
    else
      puts "No steps found in rule"
    end
    
    # Определяем объект для тестирования
    object = nil
    event = rule.event
    
    if incase_id
      object = account.incases.find_by(id: incase_id)
      unless object
        puts "❌ Incase ##{incase_id} not found"
        exit 1
      end
      puts "--- Test Object: Incase ---"
      puts "ID: #{object.id}"
      puts "Status: #{object.status}"
      puts "Client: #{object.client&.name} (#{object.client&.email})"
      puts "Webform: #{object.webform&.title}"
      puts ""
    elsif variant_id
      object = account.variants.find_by(id: variant_id)
      unless object
        puts "❌ Variant ##{variant_id} not found"
        exit 1
      end
      puts "--- Test Object: Variant ---"
      puts "ID: #{object.id}"
      puts "Quantity: #{object.quantity}"
      puts ""
    elsif message_id
      object = account.automation_messages.find_by(id: message_id)
      unless object
        puts "❌ AutomationMessage ##{message_id} not found"
        exit 1
      end
      puts "--- Test Object: AutomationMessage ---"
      puts "ID: #{object.id}"
      puts "Channel: #{object.channel}"
      puts "Status: #{object.status}"
      puts ""
    else
      puts "⚠️  No test object specified. Showing rule structure only."
      puts "To test execution, provide INCASE_ID, VARIANT_ID, or MESSAGE_ID"
      exit 0
    end
    
    # Строим контекст
    context = {}
    if object.is_a?(Incase)
      context = {
        incase: object,
        client: object.client,
        webform: object.webform
      }
    elsif object.is_a?(Variant)
      context = {
        variant: object,
        product: object.product
      }
    elsif object.is_a?(AutomationMessage)
      context = {
        automation_message: object,
        incase: object.incase,
        client: object.client
      }
    end
    
    # Проверяем условия перед выполнением
    puts "--- Pre-execution Check ---"
    first_step = rule.automation_rule_steps.ordered.first
    if first_step&.condition?
      conditions_array = first_step.automation_conditions.ordered.map do |cond|
        { "field" => cond.field, "operator" => cond.operator, "value" => cond.value }
      end
      condition_json = { "operator" => "AND", "conditions" => conditions_array }.to_json
      condition_result = Automation::ConditionEvaluator.new(condition_json, context).evaluate
      
      puts "First step condition check:"
      first_step.automation_conditions.ordered.each do |cond|
        evaluator = Automation::ConditionEvaluator.new(condition_json, context)
        field_value = evaluator.send(:get_field_value, cond.field)
        single_result = evaluator.send(:evaluate_single_condition, cond)
        puts "  #{cond.field} #{cond.operator} #{cond.value} → #{field_value.inspect} → #{single_result ? '✅ PASS' : '❌ FAIL'}"
      end
      puts "Overall condition result: #{condition_result ? '✅ PASS' : '❌ FAIL'}"
      puts "Will execute: #{condition_result ? 'Да branch' : 'Нет branch'}"
      puts ""
    end
    
    # Показываем все правила, которые будут выполнены
    puts "--- Rules that will execute for event '#{event}' ---"
    all_rules = account.automation_rules.active.for_event(event).order(:position)
    all_rules.each do |r|
      marker = r.id == rule.id ? "👉 " : "   "
      puts "#{marker}Rule ##{r.id}: #{r.title}"
    end
    puts ""
    
    # Запускаем правило
    puts "--- Executing Rule ---"
    messages_before = account.automation_messages.where(automation_rule: rule).count
    rule_scheduled_before = rule.scheduled_for
    
    begin
      Automation::Engine.call(
        account: account,
        event: event,
        object: object,
        context: context
      )
      puts "✅ All rules executed successfully"
    rescue => e
      puts "❌ Error executing rule: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
    
    # Проверяем, была ли запланирована пауза
    rule.reload
    if rule.scheduled_for.present? && rule_scheduled_before != rule.scheduled_for
      puts ""
      puts "⏸️  Rule has a pause scheduled:"
      puts "  Scheduled for: #{rule.scheduled_for}"
      time_until = (rule.scheduled_for - Time.zone.now).to_i
      if time_until > 0
        puts "  Time until execution: #{time_until} seconds (#{(time_until / 60.0).round(1)} minutes)"
        puts "  ⚠️  Messages will be created after the pause completes"
      end
    end
    
    # Показываем результаты
    messages_after = account.automation_messages.where(automation_rule: rule).count
    new_messages_count = messages_after - messages_before
    
    puts ""
    puts "--- Results for Rule ##{rule.id} ---"
    puts "Messages before: #{messages_before}"
    puts "Messages after: #{messages_after}"
    puts "New messages created: #{new_messages_count}"
    
    if new_messages_count > 0
      new_messages = account.automation_messages
        .where(automation_rule: rule)
        .order(created_at: :desc)
        .limit(new_messages_count)
      
      new_messages.each do |msg|
        puts ""
        puts "Message ID: #{msg.id}"
        puts "  Channel: #{msg.channel}"
        puts "  Status: #{msg.status}"
        puts "  Created: #{msg.created_at}"
        puts "  Client: #{msg.client&.name} (#{msg.client&.email})"
        if msg.subject.present?
          puts "  Subject: #{msg.subject}"
        end
        if msg.error_message.present?
          puts "  Error: #{msg.error_message}"
        end
      end
    elsif rule.scheduled_for.present?
      puts ""
      puts "ℹ️  No messages created yet - rule is paused and will continue at #{rule.scheduled_for}"
    else
      puts ""
      puts "ℹ️  No messages created. Possible reasons:"
      puts "  - Condition evaluated to false (execution went to 'Нет' branch)"
      puts "  - Rule has no action steps"
      puts "  - Action steps failed silently"
    end
    
    # Показываем все сообщения, созданные для этого события (всех правил)
    puts ""
    puts "--- All Messages Created (all rules for event '#{event}') ---"
    all_new_messages = account.automation_messages
      .where(automation_rule: all_rules)
      .where("created_at > ?", 5.seconds.ago)
      .order(created_at: :desc)
    
    if all_new_messages.any?
      all_new_messages.each do |msg|
        marker = msg.automation_rule_id == rule.id ? "👉 " : "   "
        puts "#{marker}Rule ##{msg.automation_rule_id} → Message ID: #{msg.id} | Channel: #{msg.channel} | Status: #{msg.status}"
      end
    else
      puts "No messages created in the last 5 seconds"
    end
    
    puts ""
    puts "=== Test Complete ==="
  end
end