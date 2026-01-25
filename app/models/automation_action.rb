class AutomationAction < ApplicationRecord
  belongs_to :automation_rule

  enum :kind, {
    send_email: 'send_email',
    send_email_to_users: 'send_email_to_users',
    send_sms_idgtl: 'send_sms_idgtl',
    send_sms_moizvonki: 'send_sms_moizvonki',
    send_telegram: 'send_telegram',
    change_status: 'change_status'
  }

  validates :kind, presence: true
  validates :value, presence: true
  validate :value_matches_kind

  # Маппинг для определения семантики value
  VALUE_MAPPING = {
    'send_email' => {
      type: 'integer',
      label: 'ID шаблона сообщения',
      validation: ->(value) { value.present? && value.to_i > 0 }
    },
    'send_email_to_users' => {
      type: 'integer',
      label: 'ID шаблона сообщения',
      validation: ->(value) { value.present? && value.to_i > 0 }
    },
    'send_sms_idgtl' => {
      type: 'integer',
      label: 'ID шаблона сообщения',
      validation: ->(value) { value.present? && value.to_i > 0 }
    },
    'send_sms_moizvonki' => {
      type: 'integer',
      label: 'ID шаблона сообщения',
      validation: ->(value) { value.present? && value.to_i > 0 }
    },
    'send_telegram' => {
      type: 'integer',
      label: 'ID шаблона сообщения',
      validation: ->(value) { value.present? && value.to_i > 0 }
    },
    'change_status' => {
      type: 'string',
      label: 'Статус заявки',
      validation: ->(value) { value.present? && Incase.statuses.key?(value) }
    }
  }.freeze

  # Методы для удобного доступа к значению
  def template_id
    return nil unless kind.in?(['send_email', 'send_email_to_users', 'send_sms_idgtl', 'send_sms_moizvonki', 'send_telegram'])
    value.to_i if value.present?
  end

  def status
    return nil unless kind == 'change_status'
    value
  end

  # Для обратной совместимости
  def new_status
    status
  end

  private

  def value_matches_kind
    return if kind.blank?
    return if value.blank? # Пропускаем валидацию если value пустое (будет валидироваться presence отдельно)
    
    mapping = VALUE_MAPPING[kind]
    return unless mapping

    unless mapping[:validation].call(value)
      errors.add(:value, "неверное значение для типа действия #{kind}")
    end
  end
  
end

