class StockCheckScheduleJob < ApplicationJob
  queue_as :stock_check_schedule
  # If the StockCheckSchedule record was deleted before the job runs,
  # Active Job will raise ActiveJob::DeserializationError. Discard it.
  discard_on ActiveJob::DeserializationError

  def perform(stock_check_schedule, expected_at = nil)
    # Skip if schedule was set inactive after enqueue
    return unless stock_check_schedule&.active?

    # If the schedule's planned time changed after enqueue, skip this stale job
    if expected_at.present? && stock_check_schedule.scheduled_for.present?
      return unless stock_check_schedule.scheduled_for.to_i == expected_at.to_i
    end

    account = stock_check_schedule.account
    Account.switch_to(account.id)

    Rails.logger.info "StockCheckScheduleJob: Starting stock check for Account ##{account.id} at #{Time.current}"

    # Этап 1: Запускаем сервис StockCheck
    success, result = StockCheck.new(account).call

    if success
      Rails.logger.info "StockCheckScheduleJob: Updated #{result[:variants_count]} variants, #{result[:incases_count]} incases for Account ##{account.id}"

      # Этап 2: Если StockCheck успешен и есть обновленные заявки, запускаем формирование и отправку писем
      if result[:incases_count] > 0
        notify_success, notify_result = IncaseNotifyGroupByClient.new(account).call

        if notify_success
          Rails.logger.info "StockCheckScheduleJob: Sent #{notify_result[:emails_sent]} emails, updated #{notify_result[:incases_updated]} incases to 'done' for Account ##{account.id}"
          if notify_result[:errors].present?
            Rails.logger.warn "StockCheckScheduleJob: Some errors occurred: #{notify_result[:errors].join('; ')}"
          end
        else
          Rails.logger.error "StockCheckScheduleJob: Failed to send notifications: #{notify_result} for Account ##{account.id}"
        end
      end
    else
      Rails.logger.error "StockCheckScheduleJob: Failed for Account ##{account.id}: #{result}"
    end

    # Enqueue the next occurrence if still active
    stock_check_schedule.enqueue_next_run!(from_time: Time.zone.now)
  rescue => e
    account_id = stock_check_schedule&.account_id || 'unknown'
    Rails.logger.error "StockCheckScheduleJob: Error for Account ##{account_id}: #{e.message}"
    Rails.logger.error "StockCheckScheduleJob: #{e.backtrace.join('\n')}"
    raise
  end
end
