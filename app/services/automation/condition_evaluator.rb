module Automation
  class ConditionEvaluator
    def initialize(condition_json, context)
      @condition = parse_condition(condition_json)
      @context = context.with_indifferent_access
    end

    def evaluate
      return true unless @condition.present? # Если условия нет, считаем что условие выполнено
      return true unless @condition['conditions'].is_a?(Array)
      return true if @condition['conditions'].empty? # Если условий нет, считаем что условие выполнено

      results = @condition['conditions'].map { |cond| evaluate_single_condition(cond) }

      case @condition['operator']&.upcase
      when 'AND'
        results.all?
      when 'OR'
        results.any?
      else
        results.all? # По умолчанию AND
      end
    end

    private

    def parse_condition(condition_json)
      return {} if condition_json.blank?

      if condition_json.is_a?(String)
        JSON.parse(condition_json)
      else
        condition_json
      end
    rescue JSON::ParserError => e
      Rails.logger.error "ConditionEvaluator: Invalid JSON: #{e.message}"
      {}
    end

    def evaluate_single_condition(condition)
      field = condition['field']
      operator = condition['operator']
      value = condition['value']

      return false unless field.present? && operator.present?

      field_value = get_field_value(field)

      case operator
      when 'equals'
        # Для boolean значений сравниваем напрямую или через строковое представление
        if [true, false].include?(field_value) && ['true', 'false'].include?(value.to_s.downcase)
          field_value == (value.to_s.downcase == 'true')
        else
          field_value.to_s == value.to_s
        end
      when 'not_equals'
        # Для boolean значений сравниваем напрямую или через строковое представление
        if [true, false].include?(field_value) && ['true', 'false'].include?(value.to_s.downcase)
          field_value != (value.to_s.downcase == 'true')
        else
          field_value.to_s != value.to_s
        end
      when 'contains'
        field_value.to_s.downcase.include?(value.to_s.downcase)
      when 'present'
        field_value.present?
      when 'blank'
        field_value.blank?
      when 'greater_than'
        field_value.to_f > value.to_f
      when 'less_than'
        field_value.to_f < value.to_f
      when 'is_true'
        field_value == true || field_value.to_s.downcase == 'true'
      when 'is_false'
        field_value == false || field_value.to_s.downcase == 'false'
      else
        false
      end
    end

    def get_field_value(field_path)
      parts = field_path.split('.')
      result = @context

      parts.each_with_index do |part, index|
        # Если это последний элемент и он содержит знак вопроса (метод-предикат)
        if index == parts.length - 1 && part.end_with?('?')
          method_name = part # Оставляем знак вопроса в имени метода
          # Проверяем, что предыдущий объект - это модель ActiveRecord
          if result.is_a?(ActiveRecord::Base) && result.respond_to?(method_name, true)
            return result.public_send(method_name)
          end
        end
        
        # Сначала пытаемся получить через [] (для Hash)
        if result.respond_to?(:[]) && result.is_a?(Hash)
          result = result[part]
        # Если это ActiveRecord объект, используем метод
        elsif result.is_a?(ActiveRecord::Base) && result.respond_to?(part)
          result = result.public_send(part)
        else
          return nil
        end
        
        return nil if result.nil?
      end

      result
    rescue => e
      Rails.logger.warn "ConditionEvaluator: Error getting field #{field_path}: #{e.message}"
      nil
    end
  end
end

