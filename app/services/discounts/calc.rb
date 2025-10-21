module Discounts
  class Calc
    def self.call(account:, data:)
      new(account: account, data: data).call
    end

    def initialize(account:, data:)
      @account = account
      @data = data.respond_to?(:with_indifferent_access) ? data.with_indifferent_access : data
      add_lower_price
    end

    def call
      Rails.logger.info "Discounts::Calc - processing for account #{@account.id}"
      
      result = get_discount
      
      if result.present?
        result
      else
        { errors: ['Скидка не найдена'] }
      end
    end

    private

    def get_discount
      data = {}
      
      @account.discounts.order(position: :asc).each do |discount|
        result = false
        
        begin
          template = Liquid::Template.parse(discount.rule)
          context = @data.respond_to?(:deep_stringify_keys) ? @data.deep_stringify_keys : @data.to_hash
          
          html_as_string = template.render!(context, { strict_variables: true })
          Rails.logger.info "Discount ##{discount.id} rule result: #{html_as_string}"
          
          check = html_as_string.respond_to?(:squish) ? html_as_string.squish : html_as_string.strip
          
          # Проверка условия do_work
          if check.include?('do_work')
            data['discount'] = discount.shift
            data['discount_type'] = discount.points.upcase
            data['title'] = discount.notice
            result = true
            Rails.logger.info "Discount ##{discount.id} APPLIED (do_work)"
          end
          
          # Проверка условия do_work_with_lower_price
          if check.include?('do_work_with_lower_price')
            data['discount'] = @data['lower_price']
            data['discount_type'] = 'MONEY'
            data['title'] = discount.notice
            result = true
            Rails.logger.info "Discount ##{discount.id} APPLIED (do_work_with_lower_price)"
          end
          
        rescue Liquid::Error => e
          Rails.logger.error "Liquid error for discount ##{discount.id}: #{e.message}"
          next
        rescue => e
          Rails.logger.error "Error processing discount ##{discount.id}: #{e.message}"
          next
        end
        
        # Прерываем цикл после первой примененной скидки
        break if result
      end
      
      data
    end

    # Добавляем минимальную цену товара в данные
    def add_lower_price
      return unless @data['order_lines'].present?
      
      prices = @data['order_lines'].map { |line| line['sale_price'] }.compact
      @data['lower_price'] = prices.min if prices.any?
    end
  end
end
