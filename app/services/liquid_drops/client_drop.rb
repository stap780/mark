module LiquidDrops
  class ClientDrop < ::Liquid::Drop
    def initialize(client, incases: nil)
      @client = client
      @incases = incases
    end

    def name
      @client.respond_to?(:name) ? @client.name : nil
    end

    def email
      @client.respond_to?(:email) ? @client.email : nil
    end

    def phone
      @client.respond_to?(:phone) ? @client.phone : nil
    end

    def incases
      # Возвращает все заявки клиента (для обратной совместимости)
      return [] unless @client.respond_to?(:incases)
      @client.incases.map { |i| IncaseDrop.new(i) }
    end

    def incases_for_notify
      # Если переданы конкретные incases, используем их
      # Иначе используем метод client.incases_for_notify
      incases_to_use = if @incases.present?
        @incases
      elsif @client.respond_to?(:incases_for_notify)
        @client.incases_for_notify
      else
        []
      end
      return [] if incases_to_use.empty?
      incases_to_use.map { |i| IncaseDrop.new(i) }
    end
  end
end


