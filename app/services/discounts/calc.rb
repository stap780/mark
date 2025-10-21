module Discounts
  class Calc
    def self.call(account:, data:)
      new(account: account, data: data).call
    end

  def initialize(account:, data:)
    @account = account
    @data = data.respond_to?(:with_indifferent_access) ? data.with_indifferent_access : data
    add_lower_price
    add_collections
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

    # Добавляем коллекции товаров в данные
    def add_collections
      return unless @data['order_lines'].present?
      
      @data['order_lines'].each do |line|
        # Получаем коллекции товара через API Insales
        colls = get_product_collections(line['product_id'])
        line['colls'] = colls
      end
    end

    # Получаем коллекции товара через API Insales
    def get_product_collections(product_id)
      return [] unless product_id.present?
      
      begin
        # Получаем данные товара через API Insales
        insales_api = @account.insales.first
        return [] unless insales_api.present?
        
        # Инициализируем API
        insales_api.api_init
        
        # Получаем товар из Insales
        ins_product = InsalesApi::Product.find(product_id)
        
        # Получаем коллекции товара
        collection_ids = ins_product.try(:collection_ids) || []
        
        # Получаем названия коллекций
        colls = collection_ids.map do |id|
          begin
            collection = InsalesApi::Collection.find(id)
            collection.try(:title)
          rescue => e
            Rails.logger.error "Error getting collection #{id}: #{e.message}"
            nil
          end
        end.compact
        
        colls
      rescue => e
        Rails.logger.error "Error getting collections for product #{product_id}: #{e.message}"
        []
      end
    end
  end
end
