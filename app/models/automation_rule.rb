class AutomationRule < ApplicationRecord
  include AccountScoped
  belongs_to :account
  has_many :automation_actions, dependent: :destroy
  has_many :automation_conditions, dependent: :destroy
  accepts_nested_attributes_for :automation_actions, allow_destroy: true
  accepts_nested_attributes_for :automation_conditions, allow_destroy: true

  enum :condition_type, { simple: 'simple', liquid: 'liquid' }

  scope :active, -> { where(active: true) }
  scope :for_event, ->(event) { where(event: event) }
  scope :with_delay, -> { where('delay_seconds > 0') }
  scope :without_delay, -> { where(delay_seconds: 0) }

  EVENTS = {
    'incase.created.order' => 'Заявка создана (заказ)',
    'incase.created.notify' => 'Заявка создана (уведомление)',
    'incase.created.preorder' => 'Заявка создана (предзаказ)',
    'incase.created.abandoned_cart' => 'Заявка создана (брошенная корзина)',
    'incase.created.custom' => 'Заявка создана (кастомная форма)',
    'incase.updated' => 'Заявка обновлена',
    'variant.back_in_stock' => 'Товар появился в наличии'
  }.freeze

  validates :title, :event, presence: true
  validates :event, inclusion: { in: EVENTS.keys }
  validates :delay_seconds, numericality: { greater_than_or_equal_to: 0 }
  validate :validate_condition_format

  before_save :build_condition_json
  after_update :handle_delay_change, if: :saved_change_to_delay_seconds?
  after_update :handle_active_change, if: :saved_change_to_active?
  before_destroy :cancel_pending_job

  def delayed?
    delay_seconds.to_i > 0
  end

  def scheduled_at(from_time: Time.zone.now)
    return nil unless delayed?
    from_time + delay_seconds.seconds
  end

  def enqueue_delayed_execution!(account:, event:, object:, context: {})
    return unless active && delayed?

    ts = scheduled_at
    return unless ts

    update_columns(scheduled_for: ts)

    job = AutomationRuleExecutionJob.set(wait_until: ts).perform_later(
      account_id: account.id,
      rule_id: id,
      event: event,
      object_type: object.class.name,
      object_id: object.id,
      context: context,
      expected_at: ts
    )

    update_columns(active_job_id: job.job_id)
  end

  def cancel_pending_job
    return if active_job_id.blank?

    if defined?(SolidQueue::Job)
      SolidQueue::Job.where(active_job_id: active_job_id, finished_at: nil).delete_all
    end
    if defined?(SolidQueue::ScheduledExecution)
      SolidQueue::ScheduledExecution.joins(:job)
                                    .where(solid_queue_jobs: { active_job_id: active_job_id })
                                    .delete_all
    end

    update_columns(active_job_id: nil, scheduled_for: nil)
  rescue => e
    Rails.logger.warn("AutomationRule##{id}: failed to cancel pending job #{active_job_id}: #{e.message}")
  end

  private

  def handle_delay_change
    cancel_pending_job
  end

  def handle_active_change
    cancel_pending_job unless active
  end

  def validate_condition_format
    return if condition.blank? && !persisted?

    # Для persisted записей проверяем наличие хотя бы одного условия
    if persisted? && automation_conditions.empty?
      errors.add(:base, "должно быть хотя бы одно условие")
      return
    end

    return if condition.blank?

    case condition_type
    when 'simple'
      validate_json_condition
    when 'liquid'
      validate_liquid_condition
    end
  end

  def validate_json_condition
    parsed = JSON.parse(condition)

    unless parsed.is_a?(Hash)
      errors.add(:condition, "должен быть объектом JSON")
      return
    end

    unless ['AND', 'OR'].include?(parsed['operator']&.upcase)
      errors.add(:condition, "оператор должен быть AND или OR")
    end

    unless parsed['conditions'].is_a?(Array)
      errors.add(:condition, "условия должны быть массивом")
      return
    end

    parsed['conditions'].each_with_index do |cond, index|
      unless cond.is_a?(Hash)
        errors.add(:condition, "условие ##{index + 1} должно быть объектом")
        next
      end

      unless cond['field'].present?
        errors.add(:condition, "условие ##{index + 1} должно содержать поле 'field'")
      end

      unless cond['operator'].present?
        errors.add(:condition, "условие ##{index + 1} должно содержать оператор")
      end
    end
  rescue JSON::ParserError => e
    errors.add(:condition, "невалидный JSON: #{e.message}")
  end

  def validate_liquid_condition
    Liquid::Template.parse(condition)
  rescue Liquid::Error => e
    errors.add(:condition, "ошибка Liquid: #{e.message}")
  end

  def build_condition_json
    return unless persisted? && condition_type == 'simple'

    conditions_array = automation_conditions.ordered.map do |cond|
      {
        'field' => cond.field,
        'operator' => cond.operator,
        'value' => cond.value
      }
    end

    self.condition = {
      'operator' => logic_operator || 'AND',
      'conditions' => conditions_array
    }.to_json
  end
end

