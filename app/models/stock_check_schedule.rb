class StockCheckSchedule < ApplicationRecord
  include ActionView::RecordIdentifier
  include AccountScoped
  belongs_to :account

  after_create_commit { 
    broadcast_append_to dom_id(account, :stock_check_schedules), 
    target: dom_id(account, :stock_check_schedules), 
    partial: "stock_check_schedules/stock_check_schedule", 
    locals: { current_account: account, stock_check_schedule: self } 
  }
  after_update_commit { 
    broadcast_replace_to dom_id(account, :stock_check_schedules),
    target: dom_id(account, dom_id(self)),
    partial: "stock_check_schedules/stock_check_schedule",
    locals: { current_account: account, stock_check_schedule: self } 
  }
  after_destroy_commit { 
    broadcast_remove_to dom_id(account, :stock_check_schedules), 
    target: dom_id(account, dom_id(self))
  }

  RECURRENCES = %w[daily].freeze

  validates :time, presence: true, if: :active?
  validates :time, uniqueness: { scope: :account_id }
  validates :recurrence, inclusion: { in: RECURRENCES }

  after_commit :enqueue_on_create, on: :create
  after_update :handle_enqueue_on_update
  before_destroy :cancel_pending_job

  # Compute the next run at given time-of-day in app timezone
  def next_run_at(from_time: Time.zone.now)
    return nil if time.blank?
    h, m = time.split(":").map(&:to_i)
    candidate = from_time.in_time_zone.change(hour: h, min: m, sec: 0)
    candidate += 1.day if candidate <= from_time
    candidate
  end

  def enqueue_run!
    return unless active
    ts = next_run_at
    return unless ts
    update_columns(scheduled_for: ts)
    job = StockCheckScheduleJob.set(wait_until: ts).perform_later(self, ts)
    update_columns(active_job_id: job.job_id)
  end

  def enqueue_next_run!(from_time: Time.zone.now)
    return unless active
    ts = next_run_at(from_time: from_time + 1.minute)
    return unless ts
    update_columns(scheduled_for: ts)
    job = StockCheckScheduleJob.set(wait_until: ts).perform_later(self, ts)
    update_columns(active_job_id: job.job_id)
  end

  private

  # Enqueue initial job after creation when active and time present
  def enqueue_on_create
    enqueue_run! if active && time.present?
  end

  # On updates, only react to meaningful changes
  def handle_enqueue_on_update
    if saved_change_to_time? || saved_change_to_recurrence?
      # Time or recurrence changed: replace or cancel
      cancel_pending_job
      enqueue_run! if active && time.present?
    elsif saved_change_to_active?
      # Active toggled: enqueue only when activated and time exists; cancel when deactivated
      if active && time.present?
        enqueue_run!
      else
        cancel_pending_job
      end
    end
  end

  # Remove pending scheduled job if present
  def cancel_pending_job
    return if active_job_id.blank?
    # Delete the Solid Queue job row(s) matching this active_job_id
    if defined?(SolidQueue::Job)
      SolidQueue::Job.where(active_job_id: active_job_id, finished_at: nil).delete_all
    end
    if defined?(SolidQueue::ScheduledExecution)
      SolidQueue::ScheduledExecution.joins(:job).where(solid_queue_jobs: { active_job_id: active_job_id }).delete_all
    end
    update_columns(active_job_id: nil)
  rescue => e
    Rails.logger.warn("StockCheckSchedule##{id}: failed to cancel pending job #{active_job_id}: #{e.message}")
  end

end

