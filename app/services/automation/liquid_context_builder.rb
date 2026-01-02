module Automation
  class LiquidContextBuilder
    # Строит контекст для Liquid из доменных объектов.
    #
    # Пример структуры в Liquid:
    #   incase  -> LiquidDrops::IncaseDrop
    #   client  -> LiquidDrops::ClientDrop (с методами incases и incases_for_notify)
    #   webform -> LiquidDrops::WebformDrop
    #   variants -> Array of LiquidDrops::VariantDrop
    #
    # В шаблоне можно использовать: {% for incase in client.incases_for_notify %}
    # client.incases_for_notify возвращает заявки со статусом in_progress и типом notify
    #
    # extra – для произвольных дополнительных ключей, если они понадобятся позже.
    def self.build(incase: nil, client: nil, webform: nil, variants: nil, user: nil, account: nil, extra: {})
      context = {}

      context['incase']  = LiquidDrops::IncaseDrop.new(incase)   if incase
      context['client']  = LiquidDrops::ClientDrop.new(client)   if client
      context['webform'] = LiquidDrops::WebformDrop.new(webform) if webform
      context['user']    = LiquidDrops::UserDrop.new(user, account: account) if user
      
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


