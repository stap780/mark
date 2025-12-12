module Automation
  class Engine
    def self.call(account:, event:, object:, context: {})
      new(account: account, event: event, object: object, context: context).call
    end

    def initialize(account:, event:, object:, context: {})
      @account = account
      @event = event
      @object = object
      @context = build_context(context)
    end

    def call
      rules = find_rules
      rules.each do |rule|
        if rule.delayed?
          # Отложенное выполнение через метод модели (по аналогии с ImportSchedule)
          rule.enqueue_delayed_execution!(
            account: @account,
            event: @event,
            object: @object,
            context: @context
          )
        else
          # Немедленное выполнение
          process_rule(rule)
        end
      end
    end

    def execute_rule(rule)
      process_rule(rule)
    end

    private

    def find_rules
      @account.automation_rules
              .active
              .for_event(@event)
              .order(:position)
    end

    def process_rule(rule)
      return unless evaluate_condition(rule)

      rule.automation_actions.each do |action|
        execute_action(action)
      end
    rescue => e
      Rails.logger.error "Automation rule ##{rule.id} error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # НЕ raise - продолжаем выполнение других правил
    end

    def evaluate_condition(rule)
      case rule.condition_type
      when 'simple'
        Automation::ConditionEvaluator.new(rule.condition, @context).evaluate
      when 'liquid'
        Automation::LiquidEvaluator.new(rule.condition, @context).evaluate
      else
        false
      end
    end

    def execute_action(action)
      Automation::ActionExecutor.new(action, @context, @account).call
    end

    def build_context(base_context)
      {
        'incase' => base_context[:incase] || @object,
        'client' => base_context[:client] || @object.try(:client),
        'webform' => base_context[:webform] || @object.try(:webform),
        'variant' => base_context[:variant] || @object,
        'product' => base_context[:product] || @object.try(:product)
      }.compact
    end
  end
end

