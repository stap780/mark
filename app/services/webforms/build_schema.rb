module Webforms
  class BuildSchema
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
        settings: merged_settings,
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
      
      {
        name: f.name,
        label: f.label,
        type: f.field_type,
        required: f.required,
        settings: merged_settings
      }
    end
  end
end


