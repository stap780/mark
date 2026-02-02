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
      rules.each { |rule| process_rule(rule) }
    end

    def execute_rule(rule)
      process_rule(rule)
    end

    def execute_rule_from_step(rule, step_id)
      step = rule.automation_rule_steps.find_by(id: step_id)
      return unless step

      process_from_step(rule, step)
    end

    private

    def find_rules
      return [] if @event.blank?

      @account.automation_rules
              .active
              .for_event(@event)
              .order(:position)
    end

    def process_rule(rule)
      first_step = rule.automation_rule_steps.ordered.first
      return unless first_step

      process_from_step(rule, first_step)
    rescue => e
      Rails.logger.error "Automation rule ##{rule.id} error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    def process_from_step(rule, step)
      case step.step_type
      when "condition"
        result = evaluate_step_condition(step)
        next_step = result ? step.next_step : step.next_step_when_false
        process_from_step(rule, next_step) if next_step
      when "pause"
        enqueue_pause_resume(rule, step)
      when "action"
        execute_step_action(step)
        process_from_step(rule, step.next_step) if step.next_step
      end
    rescue => e
      Rails.logger.error "Automation step ##{step.id} error: #{e.message}"
      raise
    end

    def evaluate_step_condition(step)
      return false if step.automation_conditions.empty?

      conditions_array = step.automation_conditions.ordered.map do |cond|
        { "field" => cond.field, "operator" => cond.operator, "value" => cond.value }
      end
      condition_json = { "operator" => "AND", "conditions" => conditions_array }.to_json
      Automation::ConditionEvaluator.new(condition_json, @context).evaluate
    end

    def enqueue_pause_resume(rule, step)
      delay_seconds = step.delay_seconds.to_i
      return process_from_step(rule, step.next_step) if step.next_step && delay_seconds <= 0

      unless step.next_step
        Rails.logger.warn "AutomationRule ##{rule.id} pause step ##{step.id} has no next_step"
        return
      end

      run_at = Time.zone.now + delay_seconds.seconds
      rule.update_columns(scheduled_for: run_at)

      job = AutomationRuleExecutionJob.set(wait_until: run_at).perform_later(
        account_id: @account.id,
        rule_id: rule.id,
        event: nil,
        object_type: nil,
        object_id: nil,
        context: @context.deep_stringify_keys,
        resume_from_step_id: step.next_step.id,
        expected_at: run_at.to_i
      )
      rule.update_columns(active_job_id: job.job_id)
    end

    def execute_step_action(step)
      return unless step.automation_action

      execute_action(step.automation_action)
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
      context = {
        'incase' => base_context[:incase] || @object,
        'client' => base_context[:client] || @object.try(:client),
        'webform' => base_context[:webform] || @object.try(:webform),
        'variant' => base_context[:variant] || @object,
        'product' => base_context[:product] || @object.try(:product)
      }
      
      # Для событий automation_message.* объект - это AutomationMessage
      # Добавляем его в контекст и извлекаем связанные объекты
      if @event.to_s.start_with?('automation_message.')
        context['automation_message'] = @object
        # Извлекаем связанные объекты из AutomationMessage
        if @object.respond_to?(:incase) && @object.incase
          context['incase'] ||= @object.incase
        end
        if @object.respond_to?(:client) && @object.client
          context['client'] ||= @object.client
        end
        if context['incase'] && context['incase'].respond_to?(:webform)
          context['webform'] ||= context['incase'].webform
        end
      end
      
      context.compact
    end
  end
end

