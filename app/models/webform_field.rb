class WebformField < ApplicationRecord
  include WebformSettings
  include ActionView::RecordIdentifier
  belongs_to :webform
  has_one_attached :image

  acts_as_list scope: :webform_id, column: :position

  validates :name, :label, :field_type, presence: true
  validates :name, uniqueness: { scope: :webform_id }
  validates :name, format: { with: /\A[a-z0-9_]+\z/, message: "должен содержать только латинские буквы, цифры и подчеркивания" }

  before_validation :generate_name_from_label, if: -> { name.blank? && label.present? }

  FIELD_TYPES = [
    ['paragraph','paragraph'],
    ['text','text'],
    ['email','email'],
    ['textarea','textarea'],
    ['phone','phone'],
    ['number','number'],
    ['checkbox','checkbox'],
    ['select','select'],
    ['button','button'],
    ['image','image']
  ]

  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    ["webform", "image"]
  end

  # Методы для работы с опциями select
  def select_options_array
    return [] if select_options.blank?
    select_options.split("\n").map(&:strip).reject(&:blank?)
  end

  def select_options_array=(options)
    self.select_options = options.is_a?(Array) ? options.join("\n") : options.to_s
  end

  private

  def generate_name_from_label
    # Транслитерация русского текста в латиницу
    transliterated = transliterate(label)
    # Убираем все кроме букв, цифр и пробелов, заменяем пробелы на подчеркивания
    self.name = transliterated.downcase
      .gsub(/[^a-z0-9\s]/, '')
      .gsub(/\s+/, '_')
      .gsub(/_+/, '_')
      .gsub(/^_|_$/, '')
    
    # Если name пустой или слишком короткий, используем fallback
    if name.blank? || name.length < 2
      self.name = "field_#{SecureRandom.hex(4)}"
    end
    
    # Убеждаемся что name уникален в рамках webform
    ensure_unique_name
  end

  def ensure_unique_name
    base_name = name
    counter = 1
    while webform.webform_fields.where.not(id: id || 0).exists?(name: name)
      self.name = "#{base_name}_#{counter}"
      counter += 1
    end
  end

  def transliterate(text)
    # Простая транслитерация русского текста в латиницу
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

  def validate_image_size
    return unless image.attached?

    # Валидация размера файла (например, максимум 10 МБ)
    if image.blob.byte_size > 1.megabytes
      errors.add(:image, 'is too big (maximum 1 MB)')
    end
  end

  def validate_image_type
    return unless image.attached?

    acceptable_types = ["image/jpeg", "image/png", "image/gif", "image/webp"]
    unless acceptable_types.include?(image.blob.content_type)
      errors.add(:image, 'must be a JPEG, PNG, GIF or WebP')
    end
  end

end


