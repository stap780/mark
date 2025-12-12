module Automation
  class LiquidEvaluator
    def initialize(condition_liquid, context)
      @condition = condition_liquid
      @context = context.with_indifferent_access
    end

    def evaluate
      return false if @condition.blank?

      begin
        template = Liquid::Template.parse(@condition)
        rendered = template.render(@context.deep_stringify_keys, { strict_variables: false })

        # Проверяем наличие маркера "do_work" (как в Discounts::Calc)
        check = rendered.respond_to?(:squish) ? rendered.squish : rendered.strip
        check.include?('do_work')
      rescue Liquid::Error => e
        Rails.logger.error "LiquidEvaluator: Liquid error: #{e.message}"
        false
      rescue => e
        Rails.logger.error "LiquidEvaluator: Error: #{e.message}"
        false
      end
    end
  end
end

