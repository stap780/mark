class SimplifyAutomationActions < ActiveRecord::Migration[8.0]
  def up
    # Добавляем новое поле value (nullable для миграции)
    add_column :automation_actions, :value, :string

    # Мигрируем данные из settings в value
    AutomationAction.reset_column_information
    AutomationAction.find_each do |action|
      next unless action.settings.present?
      
      case action.kind
      when 'send_email'
        template_id = action.settings&.dig('template_id')
        action.update_column(:value, template_id.to_s) if template_id.present?
      when 'change_status'
        status = action.settings&.dig('status')
        action.update_column(:value, status) if status.present?
      end
    end
  end

  def down
    # Восстанавливаем settings из value
    AutomationAction.reset_column_information
    AutomationAction.find_each do |action|
      settings = {}
      case action.kind
      when 'send_email'
        settings['template_id'] = action.value.to_i if action.value.present?
      when 'change_status'
        settings['status'] = action.value if action.value.present?
      end
      action.update_column(:settings, settings) if settings.any?
    end

    remove_column :automation_actions, :value
  end
end
