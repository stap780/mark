module Webforms
  class BuildSchema
    # Список ключей настроек, которые требуют единицы измерения 'px'
    PX_KEYS = %w[
      width font_size padding_x padding_y margin_x margin_y
      border_width border_radius
      box_shadow_offset_x box_shadow_offset_y box_shadow_blur box_shadow_spread
    ].freeze

    def initialize(webform)
      @webform = webform
    end

    def call
      merged_settings = @webform.merge_with_defaults(@webform.settings)
      
      {
        id: @webform.id,
        title: @webform.title,
        kind: @webform.kind,
        status: @webform.status,
        settings: normalize_settings(merged_settings),
        fields: @webform.webform_fields.order(:position).map { |f| serialize_field(f) }
      }
    end

    private

    def serialize_field(f)
      settings = f.settings
      if settings.is_a?(String) && !settings.blank?
        begin
          settings = JSON.parse(settings)
        rescue JSON::ParserError
          settings = {}
        end
      elsif settings.blank?
        settings = {}
      end
      
      merged_settings = f.merge_with_defaults(settings)
      
      field_data = {
        name: f.name,
        label: f.label,
        type: f.field_type,
        required: f.required,
        settings: normalize_settings(merged_settings)
      }
      
      # Добавляем URL изображения для image полей
      if f.field_type == 'image' && f.image.attached?
        field_data[:image_url] = Rails.application.routes.url_helpers.rails_blob_path(f.image, only_path: true)
      end
      
      field_data
    end

    def normalize_settings(settings)
      normalized = settings.dup
      
      PX_KEYS.each do |key|
        if normalized.key?(key)
          value = normalized[key]
          normalized[key] = px_value(value)
        end
      end
      
      # Для image_width_percent оставляем как есть (проценты)
      # Для image_position оставляем как есть (строка)
      if normalized.key?('image_width_percent')
        value = normalized['image_width_percent']
        normalized['image_width_percent'] = value.to_i # Убеждаемся что это число
      end
      
      normalized
    end

    def px_value(value, fallback = nil)
      return fallback if value.nil?
      
      str = value.to_s.strip
      return str if str.match?(/\A.*px\z/i) # Уже содержит 'px'
      return "#{str}px" if str.match?(/\A-?\d+(?:\.\d+)?\z/) # Число без единиц
      
      fallback
    end
  end
end


