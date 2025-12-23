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
        fields: @webform.webform_fields.order(:position).map { |f| serialize_field(f) },
        # Настройки триггеров теперь берём из отдельных колонок webforms
        trigger: {
          type: @webform.trigger_type.presence || default_trigger_type_for_kind(@webform.kind),
          value: @webform.trigger_value,
          show_delay: @webform.show_delay || 0,
          show_once_per_session: @webform.show_once_per_session != false,
          show_frequency_days: @webform.show_frequency_days,
          target_pages: @webform.target_pages_array,
          exclude_pages: @webform.exclude_pages_array,
          target_devices: @webform.target_devices_array,
          cookie_name: @webform.cookie_name.presence || "webform_#{@webform.id}_shown"
        }
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
      # Пытаемся сразу отдать прямой S3/Timeweb URL, чтобы не гонять лишний редирект через Rails.
      if f.field_type == 'image' && f.image.attached?
        begin
          service = f.image.service
          if service.respond_to?(:bucket) && service.bucket.respond_to?(:name)
            # Прямой S3/Timeweb URL (как в t2/app/models/image.rb#s3_url)
            field_data[:image_url] = "https://s3.timeweb.cloud/#{service.bucket.name}/#{f.image.blob.key}"
          else
            # Фоллбэк — относительный путь через ActiveStorage
            field_data[:image_url] = Rails.application.routes.url_helpers.rails_blob_path(f.image, only_path: true)
          end
        rescue
          field_data[:image_url] = Rails.application.routes.url_helpers.rails_blob_path(f.image, only_path: true)
        end
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

    def default_trigger_type_for_kind(kind)
      case kind
      when 'custom'
        'manual'
      when 'notify', 'preorder'
        'event'
      when 'abandoned_cart'
        'activity'
      else
        nil
      end
    end
  end
end


