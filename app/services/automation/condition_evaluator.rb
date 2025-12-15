module Automation
  class ConditionEvaluator
    def initialize(condition_json, context)
      @condition = parse_condition(condition_json)
      @context = context.with_indifferent_access
    end

    def evaluate
      return false unless @condition.present?
      return false unless @condition['conditions'].is_a?(Array)
      return false if @condition['conditions'].empty?

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
        field_value.to_s == value.to_s
      when 'not_equals'
        field_value.to_s != value.to_s
      when 'contains'
        field_value.to_s.include?(value.to_s)
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
          method_name = part[0..-2] # Убираем знак вопроса
          # Проверяем, что предыдущий объект - это модель ActiveRecord
          if result.is_a?(ActiveRecord::Base) && result.respond_to?(method_name)
            return result.public_send(method_name)
          end
        end
        
        return nil unless result.respond_to?(:[])
        result = result[part]
        return nil if result.nil?
      end

      result
    rescue => e
      Rails.logger.warn "ConditionEvaluator: Error getting field #{field_path}: #{e.message}"
      nil
    end
  end
end

