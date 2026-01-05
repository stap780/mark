module LiquidDrops
  class ProductDrop < Liquid::Drop
    def initialize(product)
      @product = product
    end

    def id
      @product.id
    end

    def title
      @product.title
    end
  end
end

