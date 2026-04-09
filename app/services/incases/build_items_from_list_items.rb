# frozen_string_literal: true

module Incases
  # Собирает атрибуты Item для заявки из позиций списка клиента (list_items).
  class BuildItemsFromListItems
    def initialize(list:, client:)
      @list = list
      @client = client
    end

    def call
      rows = []
      @list.list_items.where(client_id: @client.id).includes(:item).find_each do |li|
        variant = resolve_variant(li)
        next unless variant

        product = variant.product
        rows << {
          product_id: product.id,
          variant_id: variant.id,
          quantity: 1,
          price: variant.price || 0
        }
      end
      rows
    end

    private

    def resolve_variant(li)
      case li.item
      when Variant
        li.item
      when Product
        li.item.variants.order(:id).first
      else
        nil
      end
    end
  end
end
