module Automation
  class LiquidContextBuilder
    # Строит контекст для Liquid из доменных объектов.
    #
    # Пример структуры в Liquid:
    #   incase  -> LiquidDrops::IncaseDrop
    #   client  -> LiquidDrops::ClientDrop (с методами incases и incases_for_notify)
    #   webform -> LiquidDrops::WebformDrop
    #   variants -> Array of LiquidDrops::VariantDrop
    #   variant -> LiquidDrops::VariantDrop (для события variant.back_in_stock)
    #   product -> LiquidDrops::ProductDrop (для события variant.back_in_stock)
    #
    # В шаблоне можно использовать: {% for incase in client.incases_for_notify %}
    # client.incases_for_notify возвращает заявки со статусом in_progress и типом notify
    #
    # extra – для произвольных дополнительных ключей, если они понадобятся позже.
    def self.build(incase: nil, client: nil, client_incases: nil, webform: nil, variants: nil, variant: nil, product: nil, user: nil, account: nil, extra: {})
      context = {}

      context['incase']  = LiquidDrops::IncaseDrop.new(incase)   if incase
      context['client']  = LiquidDrops::ClientDrop.new(client, incases: client_incases)   if client
      context['webform'] = LiquidDrops::WebformDrop.new(webform) if webform
      context['user']    = LiquidDrops::UserDrop.new(user, account: account) if user
      
      # Добавляем вариант, если передан (для события variant.back_in_stock)
      if variant
        context['variant'] = LiquidDrops::VariantDrop.new(variant)
      end
      
      # Добавляем продукт, если передан (для события variant.back_in_stock)
      if product
        context['product'] = LiquidDrops::ProductDrop.new(product)
      end
      
      # Добавляем список вариантов, если передан
      if variants.present?
        context['variants'] = variants.map { |v| LiquidDrops::VariantDrop.new(v) }
      end

      (extra || {}).each do |key, value|
        context[key.to_s] = value
      end

      context
    end
  end
end


