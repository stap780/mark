module LiquidDrops
  class VariantDrop < Liquid::Drop
    def initialize(variant)
      @variant = variant
    end

    def id
      @variant.id
    end

    def title
      @variant.product.title
    end

    def product_title
      @variant.product.title
    end

    def quantity
      @variant.quantity
    end

    def price
      @variant.price
    end

    def sku
      @variant.sku
    end

    def barcode
      @variant.barcode
    end
  end
end

