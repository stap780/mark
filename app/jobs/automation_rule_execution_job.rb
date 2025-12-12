class AutomationRuleExecutionJob < ApplicationJob
  queue_as :default

  # Если правило было удалено или деактивировано, игнорируем job
  # (как в ImportScheduleJob)
  discard_on ActiveJob::DeserializationError

  def perform(account_id:, rule_id:, event:, object_type:, object_id:, context:, expected_at: nil)
    account = Account.find(account_id)
    rule = account.automation_rules.find(rule_id)

    # Проверяем, что правило все еще активно (по аналогии с ImportSchedule)
    return unless rule&.active?

    # Проверяем, что время выполнения не изменилось (защита от stale jobs)
    # Это предотвращает выполнение устаревших jobs, если delay_seconds был изменен
    if expected_at.present? && rule.scheduled_for.present?
      return unless rule.scheduled_for.to_i == expected_at.to_i
    end

    object = object_type.constantize.find(object_id)

    # Восстанавливаем контекст
    restored_context = context.symbolize_keys

    # Выполняем правило
    engine = Automation::Engine.new(
      account: account,
      event: event,
      object: object,
      context: restored_context
    )
    engine.execute_rule(rule)

    # Очищаем scheduled_for и active_job_id после выполнения
    rule.update_columns(scheduled_for: nil, active_job_id: nil)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "AutomationRuleExecutionJob: #{e.message}"
  rescue => e
    Rails.logger.error "AutomationRuleExecutionJob error: #{e.message}"
    raise
  end
end

