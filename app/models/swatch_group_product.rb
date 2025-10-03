class SwatchGroupProduct < ApplicationRecord
  belongs_to :swatch_group, inverse_of: :swatch_group_products
  belongs_to :product, optional: true

  has_one_attached :image

  validates :swatch_value, presence: true
  validates :product_id, uniqueness: { scope: :swatch_group_id }, allow_nil: true
  validate :image_must_be_image_type
  validate :image_dimensions_within_limit

  scope :ordered, -> { order(:id) }

  def image_s3_url
    return nil unless image.attached?

    "https://s3.timeweb.cloud/#{image.blob.service.bucket.name}/#{image.blob.key}"
  end

  private

  def image_must_be_image_type
    return unless image.attached?
    content_type = image.blob.content_type
    unless content_type.present? && content_type.start_with?("image/")
      errors.add(:image, "must be an image")
    end
  end

  def image_dimensions_within_limit
    return unless image.attached?
    width  = image.blob.metadata[:width]
    height = image.blob.metadata[:height]

    # Try to analyze if metadata missing
    if width.blank? || height.blank?
      begin
        image.analyze
        image.blob.reload
        width  = image.blob.metadata[:width]
        height = image.blob.metadata[:height]
      rescue StandardError
        # If we cannot analyze now, skip strict validation to avoid blocking save
        return
      end
    end

    if width.to_i > 300 || height.to_i > 300
      errors.add(:image, "must be at most 300x300px")
    end
    puts "width => #{width}"
    puts "height => #{height}"
    puts "width.to_i > 300 => #{width.to_i > 300}"
    puts "height.to_i > 300 => #{height.to_i > 300}"
  end
end
