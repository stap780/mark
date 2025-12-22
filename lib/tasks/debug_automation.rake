namespace :debug do
  desc "Debug automation rule execution"
  task automation: :environment do
    account_id = ENV['ACCOUNT_ID'] || 2
    incase_id = ENV['INCASE_ID']
    rule_id = ENV['RULE_ID']
    
    Account.switch_to(account_id)
    account = Account.find(account_id)
    
    if incase_id
      incase = account.incases.find(incase_id)
      puts "=== Checking automation for incase ##{incase.id} ==="
      puts "Incase: #{incase.inspect}"
      puts "Webform: #{incase.webform&.title} (id: #{incase.webform_id})"
      puts "Client: #{incase.client&.name} (id: #{incase.client_id})"
      puts ""
      
      # Находим правила для события incase.created
      rules = account.automation_rules.active.for_event('incase.created')
      puts "Found #{rules.count} active rules for event 'incase.created'"
      puts ""
      
      rules.each do |rule|
        puts "--- Rule ##{rule.id}: #{rule.title} ---"
        puts "Active: #{rule.active}"
        puts "Event: #{rule.event}"
        puts "Condition type: #{rule.condition_type}"
        puts "Logic operator: #{rule.logic_operator}"
        puts "Condition JSON: #{rule.condition}"
        puts ""
        
        # Парсим условие
        condition_data = rule.condition.is_a?(String) ? JSON.parse(rule.condition) : rule.condition
        puts "Parsed condition: #{condition_data.inspect}"
        puts ""
        
        # Строим контекст
        context = {
          'incase' => incase,
          'client' => incase.client,
          'webform' => incase.webform
        }
        puts "Context:"
        context.each do |key, value|
          puts "  #{key}: #{value.class} (id: #{value&.id})"
        end
        puts ""
        
        # Проверяем каждое условие
        if condition_data['conditions'].is_a?(Array)
          puts "Conditions (#{condition_data['conditions'].count}):"
          condition_data['conditions'].each_with_index do |cond, idx|
            puts "  Condition ##{idx + 1}:"
            puts "    Field: #{cond['field']}"
            puts "    Operator: #{cond['operator']}"
            puts "    Value: #{cond['value']}"
            
            # Получаем значение поля
            evaluator = Automation::ConditionEvaluator.new(rule.condition, context)
            field_value = evaluator.send(:get_field_value, cond['field'])
            puts "    Field value: #{field_value.inspect} (#{field_value.class})"
            
            # Проверяем условие
            result = evaluator.send(:evaluate_single_condition, cond)
            puts "    Result: #{result ? '✓ PASS' : '✗ FAIL'}"
            puts ""
          end
          
          # Общая проверка
          overall_result = Automation::ConditionEvaluator.new(rule.condition, context).evaluate
          puts "Overall result: #{overall_result ? '✓ PASS' : '✗ FAIL'}"
        else
          puts "No conditions found or invalid format"
        end
        
        puts ""
        puts "Actions (#{rule.automation_actions.count}):"
        rule.automation_actions.each do |action|
          puts "  - #{action.kind}: #{action.settings}"
        end
        puts ""
        puts "=" * 60
        puts ""
      end
    elsif rule_id
      rule = account.automation_rules.find(rule_id)
      puts "=== Rule ##{rule.id}: #{rule.title} ==="
      puts "Active: #{rule.active}"
      puts "Event: #{rule.event}"
      puts "Condition: #{rule.condition}"
      puts ""
      
      # Показываем последнюю заявку для тестирования
      last_incase = account.incases.last
      if last_incase
        puts "Testing with last incase ##{last_incase.id}:"
        context = {
          'incase' => last_incase,
          'client' => last_incase.client,
          'webform' => last_incase.webform
        }
        
        result = Automation::ConditionEvaluator.new(rule.condition, context).evaluate
        puts "Result: #{result ? '✓ PASS' : '✗ FAIL'}"
      end
    else
      puts "Usage:"
      puts "  ACCOUNT_ID=2 INCASE_ID=969 rake debug:automation"
      puts "  ACCOUNT_ID=2 RULE_ID=5 rake debug:automation"
    end
  end
end

