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
    
    # Запускаем правило
    puts "--- Executing Rule ---"
    messages_before = account.automation_messages.where(automation_rule: rule).count
    
    begin
      Automation::Engine.call(
        account: account,
        event: event,
        object: object,
        context: context
      )
      puts "✅ Rule executed successfully"
    rescue => e
      puts "❌ Error executing rule: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
    
    # Показываем результаты
    messages_after = account.automation_messages.where(automation_rule: rule).count
    new_messages_count = messages_after - messages_before
    
    puts ""
    puts "--- Results ---"
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
    end
    
    puts ""
    puts "=== Test Complete ==="
  end
end