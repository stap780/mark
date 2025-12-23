class BackfillWebformTriggers < ActiveRecord::Migration[8.0]
  def up
    say_with_time "Backfilling webform trigger columns from settings" do
      Webform.reset_column_information

      Webform.find_each do |wf|
        settings = (wf.settings || {}).with_indifferent_access

        # Определяем тип триггера
        trigger_type = settings[:trigger_type].presence || Webform.default_trigger_type_for_kind(wf.kind)

        wf.trigger_type           ||= trigger_type
        wf.trigger_value          ||= settings[:trigger_value]
        wf.show_delay             ||= settings[:show_delay] || 0
        wf.show_once_per_session   = settings.key?(:show_once_per_session) ? (settings[:show_once_per_session] != false) : (wf.show_once_per_session.nil? ? true : wf.show_once_per_session)
        wf.show_frequency_days    ||= settings[:show_frequency_days]

        # target_pages / exclude_pages могли быть массивами в settings – сохраняем как строки с переносами
        if wf.target_pages.blank?
          tp = settings[:target_pages]
          wf.target_pages = tp.is_a?(Array) ? tp.join("\n") : tp
        end

        if wf.exclude_pages.blank?
          ep = settings[:exclude_pages]
          wf.exclude_pages = ep.is_a?(Array) ? ep.join("\n") : ep
        end

        wf.target_devices       ||= Array(settings[:target_devices]).join(",") if settings[:target_devices].present?
        wf.cookie_name          ||= settings[:cookie_name]

        wf.save!(validate: false)
      end
    end
  end

  def down
    # Ничего не откатываем – данные остаются в колонках.
  end
end


