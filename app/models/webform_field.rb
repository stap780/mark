class WebformField < ApplicationRecord
  include WebformSettings
  include ActionView::RecordIdentifier
  belongs_to :webform
  has_one_attached :image

  acts_as_list scope: :webform_id, column: :position

  validates :name, :label, :field_type, presence: true
  validates :name, uniqueness: { scope: :webform_id }

  FIELD_TYPES = [
    ['text','text'],
    ['email','email'],
    ['textarea','textarea'],
    ['phone','phone'],
    ['number','number'],
    ['select','select'],
    ['checkbox','checkbox'],
    ['button','button'],
    ['image','image']
  ]

  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    ["webform", "image"]
  end

  private

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


