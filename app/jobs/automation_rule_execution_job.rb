class AutomationRuleExecutionJob < ApplicationJob
  queue_as :automation_rule_execution

  # Если правило было удалено или деактивировано, игнорируем job
  # (как в ImportScheduleJob)
  discard_on ActiveJob::DeserializationError

  def perform(account_id:, rule_id:, event: nil, object_type: nil, object_id: nil, context:, expected_at: nil, resume_from_step_id: nil)
    account = Account.find(account_id)
    rule = account.automation_rules.find(rule_id)

    return unless rule&.active?

    if expected_at.present? && rule.scheduled_for.present?
      return unless rule.scheduled_for.to_i == expected_at.to_i
    end

    restored_context = context.symbolize_keys

    if resume_from_step_id.present?
      engine = Automation::Engine.new(
        account: account,
        event: nil,
        object: nil,
        context: restored_context
      )
      engine.execute_rule_from_step(rule, resume_from_step_id)
    else
      object = object_type.constantize.find(object_id)
      engine = Automation::Engine.new(
        account: account,
        event: event,
        object: object,
        context: restored_context
      )
      engine.execute_rule(rule)
    end

    rule.update_columns(scheduled_for: nil, active_job_id: nil)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "AutomationRuleExecutionJob: #{e.message}"
  rescue => e
    Rails.logger.error "AutomationRuleExecutionJob error: #{e.message}"
    raise
  end
end

