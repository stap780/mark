module LiquidDrops
  class IncaseItemDrop < ::Liquid::Drop
    def initialize(item)
      @item = item
    end

    def product_title
      if @item.respond_to?(:product) && @item.product
        @item.product.respond_to?(:title) ? @item.product.title : @item.product.to_s
      end
    end

    def product_link
      if @item.respond_to?(:product) && @item.product
        @item.product.insales_link
      end
    end

    def quantity
      @item.respond_to?(:quantity) ? @item.quantity : nil
    end

    def price
      @item.respond_to?(:price) ? @item.price : nil
    end

    def sum
      if @item.respond_to?(:sum)
        @item.sum
      else
        quantity.to_f * price.to_f
      end
    end
    
  end
end


