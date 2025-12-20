class AutomationRulesController < ApplicationController
  include OffcanvasResponder
  include ActionView::RecordIdentifier

  before_action :set_automation_rule, only: [:edit, :update, :destroy]

  def index
    @automation_rules = current_account.automation_rules.order(:position, :created_at)
  end

  def new
    @automation_rule = current_account.automation_rules.build
  end

  def create
    @automation_rule = current_account.automation_rules.build(automation_rule_params)
    @automation_rule.condition_type ||= 'simple' # Установить по умолчанию

    respond_to do |format|
      if @automation_rule.save
        flash[:success] = "Правило создано"
        format.turbo_stream { redirect_to edit_account_automation_rule_path(current_account, @automation_rule, format: :html) }
        format.html { redirect_to edit_account_automation_rule_path(current_account, @automation_rule) }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    # Обрабатываем automation_conditions_attributes перед сохранением
    process_conditions_attributes
    # Обрабатываем automation_actions_attributes перед сохранением
    process_actions_attributes
    
    respond_to do |format|
      if @automation_rule.update(automation_rule_params)
        # flash[:success] = "Правило обновлено"
        format.turbo_stream { redirect_to edit_account_automation_rule_path(current_account, @automation_rule) }
        format.html { redirect_to account_automation_rules_path(current_account), notice: t('.success')}
      else
        puts "errors: #{@automation_rule.errors.full_messages.join(' ')}"
        flash.now[:notice] = @automation_rule.errors.full_messages.join(' ')
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream {
          render turbo_stream: [
            render_turbo_flash
          ]
          # redirect_to edit_account_automation_rule_path(current_account, @automation_rule), status: :see_other 
        }
      end
    end
  end

  def destroy
    @automation_rule.destroy
    respond_to do |format|
      flash.now[:success] = t('.success')
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove( dom_id(@automation_rule, dom_id(current_account))),
          render_turbo_flash
        ]
      end
      format.html { redirect_to account_automation_rules_path(current_account), notice: t('.success') }
    end
  end

  def create_standard_scenarios_form
    # Отображаем форму в offcanvas
  end

  def create_standard_scenarios
    service = Automation::CreateStandardScenarios.new(current_account)
    
    respond_to do |format|
      service.call
      @automation_rules = current_account.automation_rules.order(:position, :created_at)
      flash.now[:success] = t('automation_rules.create_standard_scenarios.success')
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(
            dom_id(current_account, :automation_rules),
            partial: 'automation_rules/index_list',
            locals: { automation_rules: @automation_rules, current_account: current_account }
          ),
          turbo_stream.update(:offcanvas, ""),
          render_turbo_flash
        ]
      end
      format.html { redirect_to account_automation_rules_path(current_account), notice: t('automation_rules.create_standard_scenarios.success') }
    end
  rescue => e
    Rails.logger.error "Error creating standard scenarios: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    respond_to do |format|
      flash.now[:error] = "Ошибка: #{e.message}"
      format.turbo_stream do
        render turbo_stream: [
          render_turbo_flash
        ]
      end
      format.html { redirect_to account_automation_rules_path(current_account), alert: "Ошибка: #{e.message}" }
    end
  end

  private

  def set_automation_rule
    @automation_rule = current_account.automation_rules.find(params[:id])
  end

  def automation_rule_params
    params.require(:automation_rule).permit(
      :title, :event, :condition_type, :condition, :active, :delay_seconds, :position, :logic_operator,
      automation_conditions_attributes: [:id, :field, :operator, :value, :position, :_destroy],
      automation_actions_attributes: [:id, :kind, :position, :_destroy, :value]
    )
  end


  def process_conditions_attributes
    conditions_attrs = params.dig(:automation_rule, :automation_conditions_attributes)
    return unless conditions_attrs.present?

    helper = Object.new.extend(AutomationRulesHelper)

    conditions_attrs.each do |key, attrs|
      next if attrs[:_destroy] == '1' || attrs[:field].blank?

      # Используем маппинг полей напрямую
      field_mapping = AutomationRulesHelper::FIELD_MAPPING[attrs[:field]]
      next unless field_mapping

      # Устанавливаем оператор на основе поля
      current_op = attrs[:operator]
      unless current_op.present? && field_mapping[:operators].include?(current_op)
        attrs[:operator] = field_mapping[:operators].first
        
        # Устанавливаем значение на основе типа поля
        current_value = attrs[:value]
        
        case field_mapping[:type]
        when 'boolean'
          # Для boolean всегда устанавливаем 'false' если значение не подходит
          attrs[:value] = ['true', 'false'].include?(current_value) ? current_value : 'false'
        when 'enum'
          # Для enum устанавливаем первое значение из списка, если текущее не подходит
          if field_mapping[:values] && field_mapping[:values].include?(current_value)
            attrs[:value] = current_value
          elsif field_mapping[:values] && field_mapping[:values].any?
            attrs[:value] = field_mapping[:values].first
          else
            attrs[:value] = nil
          end
        when 'number'
          # Для number устанавливаем значение по умолчанию, если текущее не подходит
          if current_value.present? && current_value.to_s.match?(/^\d+$/)
            attrs[:value] = current_value
          else
            # Устанавливаем значение по умолчанию для числовых полей
            attrs[:value] = '0'
          end
        when 'string'
          # Для string оставляем как есть
          attrs[:value] = current_value
        else
          attrs[:value] = nil
        end
      end
    end
  end

  def process_actions_attributes
    # Устанавливаем первое допустимое значение при изменении kind
    actions_attrs = params.dig(:automation_rule, :automation_actions_attributes)
    return unless actions_attrs.present?

    # Собираем все позиции существующих действий
    existing_positions = @automation_rule.automation_actions.pluck(:position).compact.map(&:to_i)
    max_position = existing_positions.any? ? existing_positions.max : 0

    actions_attrs.each do |key, attrs|
      next if attrs[:_destroy] == '1' || attrs[:kind].blank?
      
      kind = attrs[:kind]
      value = attrs[:value]
      
      mapping = AutomationAction::VALUE_MAPPING[kind]
      next unless mapping
      
      # Если это новое действие (нет id) и позиция не указана или конфликтует, устанавливаем следующую
      if attrs[:id].blank?
        position = attrs[:position].to_i
        if position.zero? || existing_positions.include?(position)
          max_position += 1
          attrs[:position] = max_position
        end
      end
      
      # Проверяем, соответствует ли value новому kind
      if value.present?
        unless mapping[:validation].call(value)
          # Значение не подходит для нового типа - устанавливаем первое допустимое значение
          default_value = default_value_for_action_kind(kind)
          attrs[:value] = default_value if default_value.present?
        end
      else
        # Если value пустое, устанавливаем первое допустимое значение
        default_value = default_value_for_action_kind(kind)
        attrs[:value] = default_value if default_value.present?
      end
    end
  end

  def default_value_for_action_kind(kind)
    case kind
    when 'change_status'
      # Первый статус из списка
      Incase.statuses.keys.first
    when 'send_email'
      # Первый доступный шаблон email
      @automation_rule.account.message_templates.email.first&.id&.to_s
    else
      nil
    end
  end

end

