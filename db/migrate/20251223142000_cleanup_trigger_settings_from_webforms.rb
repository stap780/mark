class CleanupTriggerSettingsFromWebforms < ActiveRecord::Migration[8.0]
  def up
    say_with_time "Removing trigger-related keys from webforms.settings" do
      Webform.reset_column_information

      trigger_keys = %w[
        trigger_type trigger_value show_delay show_once_per_session
        show_frequency_days target_pages exclude_pages target_devices cookie_name
      ]

      Webform.find_each do |wf|
        next if wf.settings.blank?

        settings = wf.settings.is_a?(String) ? (JSON.parse(wf.settings) rescue {}) : wf.settings
        next if settings.blank?

        cleaned = settings.except(*trigger_keys)
        next if cleaned == settings

        wf.update_columns(settings: cleaned)
      end
    end
  end

  def down
    # Невозможно восстановить удалённые ключи из settings
  end
end


