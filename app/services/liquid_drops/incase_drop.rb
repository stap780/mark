module LiquidDrops
  class IncaseDrop < ::Liquid::Drop
    def initialize(incase)
      @incase = incase
    end

    def id
      @incase&.id
    end

    def status
      @incase.respond_to?(:status) ? @incase.status : nil
    end

    def created_at
      @incase.respond_to?(:created_at) ? @incase.created_at : nil
    end

    def items
      return [] unless @incase.respond_to?(:items)

      @incase.items.map do |item|
        LiquidDrops::IncaseItemDrop.new(item)
      end
    end
  end
end


