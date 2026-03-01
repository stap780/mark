# frozen_string_literal: true

class IncaseStatus < ApplicationRecord
  belongs_to :account
  has_many :incases, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: { scope: :account_id }
  validates :key, format: { with: /\A[a-z0-9_]+\z/, message: "должен содержать только латинские буквы, цифры и подчеркивания" }, allow_blank: true
  validates :name, presence: true
  validates :color, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :id) }

  before_validation :generate_key_from_name, if: -> { key.blank? && name.present? }
  before_destroy :ensure_no_incases

  DEFAULT_STATUSES = [
    { key: "new", name: "Новая", color: "bg-blue-100 text-blue-800", position: 1 },
    { key: "in_progress", name: "В работе", color: "bg-yellow-100 text-yellow-800", position: 2 },
    { key: "done", name: "Выполнена", color: "bg-green-100 text-green-800", position: 3 },
    { key: "canceled", name: "Отменена", color: "bg-red-100 text-red-800", position: 4 },
    { key: "closed", name: "Закрыта", color: "bg-gray-100 text-gray-800", position: 5 }
  ].freeze

  def self.ensure_defaults_for(account)
    return if account.incase_statuses.exists?

    DEFAULT_STATUSES.each do |attrs|
      account.incase_statuses.create!(attrs)
    end
  end

  private

  def generate_key_from_name
    transliterated = transliterate(name)
    self.key = transliterated.downcase
      .gsub(/[^a-z0-9\s]/, '')
      .gsub(/\s+/, '_')
      .gsub(/_+/, '_')
      .gsub(/^_|_$/, '')

    self.key = "status_#{SecureRandom.hex(4)}" if key.blank? || key.length < 2

    ensure_unique_key
  end

  def ensure_unique_key
    base_key = key
    counter = 1
    while account.incase_statuses.where.not(id: id || 0).exists?(key: key)
      self.key = "#{base_key}_#{counter}"
      counter += 1
    end
  end

  def transliterate(text)
    text.to_s
      .gsub(/[аА]/, 'a').gsub(/[бБ]/, 'b').gsub(/[вВ]/, 'v').gsub(/[гГ]/, 'g')
      .gsub(/[дД]/, 'd').gsub(/[еЕёЁ]/, 'e').gsub(/[жЖ]/, 'zh').gsub(/[зЗ]/, 'z')
      .gsub(/[иИ]/, 'i').gsub(/[йЙ]/, 'y').gsub(/[кК]/, 'k').gsub(/[лЛ]/, 'l')
      .gsub(/[мМ]/, 'm').gsub(/[нН]/, 'n').gsub(/[оО]/, 'o').gsub(/[пП]/, 'p')
      .gsub(/[рР]/, 'r').gsub(/[сС]/, 's').gsub(/[тТ]/, 't').gsub(/[уУ]/, 'u')
      .gsub(/[фФ]/, 'f').gsub(/[хХ]/, 'h').gsub(/[цЦ]/, 'ts').gsub(/[чЧ]/, 'ch')
      .gsub(/[шШ]/, 'sh').gsub(/[щЩ]/, 'sch').gsub(/[ъЪьЬ]/, '').gsub(/[ыЫ]/, 'y')
      .gsub(/[эЭ]/, 'e').gsub(/[юЮ]/, 'yu').gsub(/[яЯ]/, 'ya')
  end

  def ensure_no_incases
    return unless incases.exists?

    errors.add(:base, I18n.t("incase_statuses.destroy.has_incases"))
    throw(:abort)
  end
end
