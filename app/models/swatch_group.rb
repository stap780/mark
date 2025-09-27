class SwatchGroup < ApplicationRecord
  belongs_to :account
  has_many :swatch_group_products, dependent: :destroy
  has_many :products, through: :swatch_group_products

  validates :name, presence: true
  validates :option_name, presence: true

  enum :status, { active: 0, inactive: 1 }

  # Style options for product/collection page controls
  # Value is a normalized token we can interpret in the storefront/theme
  STYLE_GROUPS = {
    "Circular swatch" => [
      ["Small - Desktop", "circular_small_desktop"],
      ["Small - Mobile", "circular_small_mobile"],
      ["Medium - Desktop", "circular_medium_desktop"],
      ["Medium - Mobile", "circular_medium_mobile"],
      ["Large - Desktop", "circular_large_desktop"],
      ["Large - Mobile", "circular_large_mobile"]
    ],
    "Dropdown with label" => [
      ["Extra small", "dropdown_label_xs"],
      ["Small", "dropdown_label_sm"],
      ["Medium", "dropdown_label_md"],
      ["Large", "dropdown_label_lg"],
      ["Extra large", "dropdown_label_xl"]
    ],
    "Square button" => [
      ["Desktop - Extra small", "square_desktop_xs"],
      ["Desktop - Small", "square_desktop_sm"],
      ["Desktop - Medium", "square_desktop_md"],
      ["Desktop - Large", "square_desktop_lg"],
      ["Mobile - Small", "square_mobile_sm"],
      ["Mobile - Medium", "square_mobile_md"]
    ],
    "Do not show" => [
      ["Desktop","hide"],
      ["Mobile","hide"]
    ]
  }.freeze

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
                        target: "swatch_groups",
                        partial: 'swatch_groups/swatch_group',
                        locals: { swatch_group: self }
  end

  after_update_commit do
    broadcast_replace_to [account, :swatch_groups],
                        target: dom_id(self),
                        partial: 'swatch_groups/swatch_group',
                        locals: { swatch_group: self }
  end

  after_destroy_commit do
    broadcast_remove_to [account, :swatch_groups], target: dom_id(self)
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
