module WebformSettings
  DEFAULT = {
    'background_color' => '#ffffff',
    'width' => 500,
    'font_size' => 14,
    'font_color' => '#000000',
    'padding_x' => 12,
    'padding_y' => 12,
    'margin_x' => 0,
    'margin_y' => 0,
    'border_width' => 0,
    'border_color' => '#ddd',
    'border_radius' => 8,
    'box_shadow_offset_x' => 0,
    'box_shadow_offset_y' => 2,
    'box_shadow_blur' => 4,
    'box_shadow_spread' => 0,
    'box_shadow_color' => 'rgba(0, 0, 0, 0.12)'
  }.freeze

  def default_settings
    DEFAULT.dup
  end

  def merge_with_defaults(settings_hash = nil)
    raw_settings = settings_hash || self.settings || {}
    
    # Handle string JSON
    if raw_settings.is_a?(String) && !raw_settings.blank?
      begin
        settings = JSON.parse(raw_settings)
      rescue JSON::ParserError
        settings = {}
      end
    elsif raw_settings.blank?
      settings = {}
    else
      settings = raw_settings
    end
    
    settings = settings.with_indifferent_access if settings.respond_to?(:with_indifferent_access)
    
    default_settings.merge(settings)
  end
end