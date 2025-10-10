class SwatchGroup < ApplicationRecord
  include AccountScoped

  belongs_to :account
  has_many :swatch_group_products, dependent: :destroy
  has_many :products, through: :swatch_group_products

  accepts_nested_attributes_for :swatch_group_products, allow_destroy: true

  validates :name, presence: true
  validates :option_name, presence: true

  enum :status, { active: 0, inactive: 1 }

  # Style options for product/collection page controls
  # Value is a normalized token we can interpret in the storefront/theme
  STYLE_GROUPS = {
    "Circular swatch" => [
      ["Circular desktop - Small", "circular_small_desktop"],
      ["Circular desktop - Medium", "circular_medium_desktop"],
      ["Circular desktop - Large", "circular_large_desktop"],
      ["Circular mobile - Small", "circular_small_mobile"],
      ["Circular mobile - Medium", "circular_medium_mobile"],
      ["Circular mobile - Large", "circular_large_mobile"]
    ],
    "Dropdown with label" => [
      ["Dropdown label - Small", "dropdown_label_small"],
      ["Dropdown label - Medium", "dropdown_label_medium"],
      ["Dropdown label - Large", "dropdown_label_large"]
    ],
    "Square button" => [
      ["Square desktop - Small", "square_desktop_small"],
      ["Square desktop - Medium", "square_desktop_medium"],
      ["Square desktop - Large", "square_desktop_large"],
      ["Square mobile - Small", "square_mobile_small"],
      ["Square mobile - Medium", "square_mobile_medium"],
      ["Square mobile - Large", "square_mobile_large"]
    ],
    "Do not show" => [
      ["Desktop hide", "hide"],
      ["Mobile hide", "hide"]
    ]
  }.freeze
  SWATCH_IMAGE_SOURCE = [
    ["First product image", "first_product_image"],
    ["Second product image", "second_product_image"],
    ["Last product image", "last_product_image"],
    ["Color / custom image", "custom_color_image"]
  ].freeze

  def self.grouped_style_options
    STYLE_GROUPS
  end

  ALLOWED_STYLE_VALUES = STYLE_GROUPS.values.flatten(1).map { |(_label, value)| value }.freeze

  # Map normalized value token => human label
  STYLE_LABEL_BY_VALUE = STYLE_GROUPS.values
                                      .flatten(1)
                                      .each_with_object({}) { |(label, value), memo| memo[value] = label }
                                      .freeze

  def self.style_label_for(value)
    return nil if value.blank?
    STYLE_LABEL_BY_VALUE[value] || value
  end

  validates :product_page_style, inclusion: { in: ALLOWED_STYLE_VALUES }
  validates :collection_page_style, inclusion: { in: ALLOWED_STYLE_VALUES }

  scope :ordered, -> { order(:name) }

  include ActionView::RecordIdentifier

  after_create_commit do
    broadcast_prepend_to [account, :swatch_groups],
                        target: [account, :swatch_groups],
                        partial: "swatch_groups/swatch_group",
                        locals: { swatch_group: self }
  end

  after_update_commit do
    broadcast_replace_to [account, :swatch_groups],
                        target: [account, dom_id(self)],
                        partial: "swatch_groups/swatch_group",
                        locals: { swatch_group: self }
  end

  after_destroy_commit do
    broadcast_remove_to [account, :swatch_groups], target: [account, dom_id(self)]
  end


  def self.ransackable_attributes(auth_object = nil)
    SwatchGroup.attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[products swatch_group_products]
  end
  # Kick off JSON regeneration for this group's account
  def regenerate_json
    SwatchJsonGeneratorJob.perform_later(account_id)
    true
  end

  # Convenience: regenerate JSON for a given account or account_id
  def self.regenerate_json_for(account_or_id)
    account_id = account_or_id.is_a?(Account) ? account_or_id.id : account_or_id
    SwatchJsonGeneratorJob.perform_later(account_id)
    true
  end
end
