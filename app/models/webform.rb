class Webform < ApplicationRecord
  include ActionView::RecordIdentifier
  include AccountScoped
  include WebformSettings
  belongs_to :account
  has_many :webform_fields, dependent: :destroy
  accepts_nested_attributes_for :webform_fields, allow_destroy: true
  has_many :incases


  before_destroy :check_incases_presence

  validates :title, :kind, presence: true
  validate :validate_singleton_kind_uniqueness

  enum :status, {
    active: "active",
    inactive: "inactive"
  }, prefix: true

  KINDS = {
    order: "order",
    notify: "notify",
    preorder: "preorder",
    abandoned_cart: "abandoned_cart",
    custom: "custom"
  }.freeze

  after_create_commit :set_default_fields_and_settings

  after_destroy_commit do
    broadcast_remove_to dom_id(account, :webforms), target: dom_id(account, dom_id(self))
  end

  def self.ransackable_attributes(auth_object = nil)
    Webform.attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  private

  def set_default_fields_and_settings
    w_s_data = {
      "width": "530",
      "font_size": "16",
      "padding_x": "12",
      "padding_y": "12",
      "font_color": "#000000",
      "border_color": "#000000",
      "border_width": "0",
      "border_radius": "8",
      "box_shadow_blur": "8",
      "background_color": "#ffffff",
      "box_shadow_color": "#000000",
      "box_shadow_spread": "0",
      "box_shadow_offset_x": "0",
      "box_shadow_offset_y": "2"
    }
    w_fields_data = [
      {
        "name": "title",
        "label": "title",
        "field_type": "text",
        "required": false,
        "settings": {
          "width": "600",
          "margin_x": "10",
          "margin_y": "0",
          "font_size": "22",
          "padding_x": "0",
          "padding_y": "16",
          "font_color": "#822121",
          "border_color": "#000000",
          "border_width": "0",
          "border_radius": "8",
          "box_shadow_blur": "0",
          "background_color": "#ffffff",
          "box_shadow_color": "#000000",
          "box_shadow_spread": "0",
          "box_shadow_offset_x": "0",
          "box_shadow_offset_y": "0"
        },
        "position": 1
      },
      {
        "name": "email",
        "label": "email",
        "field_type": "email",
        "required": true,
        "settings": {
          "width": "237",
          "margin_x": "10",
          "margin_y": "0",
          "font_size": "16",
          "padding_x": "12",
          "padding_y": "12",
          "font_color": "#000000",
          "border_color": "#000000",
          "border_width": "0",
          "border_radius": "8",
          "box_shadow_blur": "5",
          "background_color": "#ffffff",
          "box_shadow_color": "#8e7171",
          "box_shadow_spread": "1",
          "box_shadow_offset_x": "1",
          "box_shadow_offset_y": "1"
        },
        "position": 2
      },
      {
        "name": "phone",
        "label": "phone",
        "field_type": "phone",
        "required": true,
        "settings": {
          "width": "237",
          "margin_x": "0",
          "margin_y": "0",
          "font_size": "16",
          "padding_x": "12",
          "padding_y": "12",
          "font_color": "#000000",
          "border_color": "#000000",
          "border_width": "0",
          "border_radius": "8",
          "box_shadow_blur": "5",
          "background_color": "#ffffff",
          "box_shadow_color": "#8e7171",
          "box_shadow_spread": "1",
          "box_shadow_offset_x": "1",
          "box_shadow_offset_y": "1"
        },
        "position": 3
      },
      {
        "name": "send",
        "label": "send",
        "field_type": "button",
        "required": false,
        "settings": {
          "width": "490",
          "margin_x": "10",
          "margin_y": "20",
          "font_size": "16",
          "padding_x": "12",
          "padding_y": "12",
          "font_color": "#f9f5f5",
          "border_color": "#8c6cd5",
          "border_width": "1",
          "border_radius": "8",
          "box_shadow_blur": "0",
          "background_color": "#9061d6",
          "box_shadow_color": "#000000",
          "box_shadow_spread": "0",
          "box_shadow_offset_x": "0",
          "box_shadow_offset_y": "0"
        },
        "position": 4
      }
    ]

    self.update(settings: w_s_data, webform_fields_attributes: w_fields_data)

  end

  def validate_singleton_kind_uniqueness
    return unless ['order', 'notify', 'preorder', 'abandoned_cart'].include?(kind)

    # Singleton per account regardless of status
    scope = self.class.where(account_id: account_id, kind: kind)
    scope = scope.where.not(id: id) if persisted?
    return unless scope.exists?

    message = case kind
              when 'notify' then 'Форма «Сообщить о поступлении» уже существует'
              when 'preorder' then 'Форма «Предзаказ» уже существует'
              when 'abandoned_cart' then 'Форма «Брошенная корзина» уже существует'
              else 'Активная форма этого типа уже существует'
              end
    errors.add(:base, message)
  end

  def check_incases_presence
    return unless incases.exists?
    errors.add(:base, "Cannot delete webform with existing incases")
    throw :abort
  end

end


