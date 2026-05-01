# frozen_string_literal: true

class Campaign < ApplicationRecord
  include AccountScoped

  belongs_to :account
  belongs_to :webform
  has_many :campaign_filter_rules, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :campaign
  has_many :incases, dependent: :nullify

  validates :title, presence: true
  validates :recurrence, inclusion: { in: %w[daily] }
  validate :time_presence_for_recurring, if: -> { recurring? && active? }

  after_create :enqueue_on_create, if: -> { should_schedule? }
  after_create :create_default_filter_rules
  after_update :handle_schedule_on_update
  before_destroy :cancel_pending_job

  def next_run_at(from_time: Time.zone.now)
    return nil if time.blank?

    h, m = time.split(":").map(&:to_i)
    candidate = from_time.in_time_zone.change(hour: h, min: m, sec: 0)
    candidate += 1.day if candidate <= from_time
    candidate
  end

  def enqueue_run!
    return unless should_schedule?
    return cancel_pending_job unless time.present?

    ts = next_run_at
    return unless ts

    update_columns(scheduled_for: ts)
    job = CampaignJob.set(wait_until: ts).perform_later(self, ts.to_i)
    update_columns(active_job_id: job.job_id)
  end

  def enqueue_next_run!(from_time: Time.zone.now)
    return unless should_schedule?
    return unless time.present?

    ts = next_run_at(from_time: from_time + 1.minute)
    return unless ts

    update_columns(scheduled_for: ts)
    job = CampaignJob.set(wait_until: ts).perform_later(self, ts.to_i)
    update_columns(active_job_id: job.job_id)
  end

  def start!
    if recurring?
      update!(active: true)
    else
      Campaigns::RunService.call(campaign: self)
      update!(active: false)
    end
  end

  def stop!
    update!(active: false)
  end

  private

  def should_schedule?
    active? && recurring? && time.present?
  end

  def enqueue_on_create
    enqueue_run!
  end

  def handle_schedule_on_update
    if saved_change_to_time? || saved_change_to_recurrence? || saved_change_to_recurring?
      cancel_pending_job
      enqueue_run! if should_schedule?
    elsif saved_change_to_active?
      if should_schedule?
        enqueue_run!
      else
        cancel_pending_job
      end
    end
  end

  def cancel_pending_job
    return if active_job_id.blank?

    if defined?(SolidQueue::Job)
      SolidQueue::Job.where(active_job_id: active_job_id, finished_at: nil).delete_all
    end
    if defined?(SolidQueue::ScheduledExecution)
      SolidQueue::ScheduledExecution.joins(:job).where(solid_queue_jobs: { active_job_id: active_job_id }).delete_all
    end
    update_columns(active_job_id: nil)
  rescue StandardError => e
    Rails.logger.warn("Campaign##{id}: failed to cancel job #{active_job_id}: #{e.message}")
  end

  def time_presence_for_recurring
    return if time.present?

    errors.add(:time, :blank)
  end

  def create_default_filter_rules
    return if campaign_filter_rules.exists?

    campaign_filter_rules.create!(
      field: "incase_days_min",
      operator: "equals",
      value: "30",
      target: :incase
    )
  end
end
