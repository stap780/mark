class Variant < ApplicationRecord
  include ActionView::RecordIdentifier
  include Varbindable

  belongs_to :product

      # Varbindable implementation
      def show_path
        Rails.application.routes.url_helpers.account_product_variant_path(
          product.account, product, self
        )
      end

      def varbinds_path
        Rails.application.routes.url_helpers.account_product_variant_varbinds_path(
          product.account, product, self
        )
      end

      def varbind_new_path
        Rails.application.routes.url_helpers.new_account_product_variant_varbind_path(
          product.account, product, self
        )
      end

      def varbind_edit_path(varbind)
        Rails.application.routes.url_helpers.edit_account_product_variant_varbind_path(
          product.account, product, self, varbind
        )
      end

  def varbind_path(varbind)
    Rails.application.routes.url_helpers.account_product_variant_varbind_path(
      product.account, product, self, varbind
    )
  end

  def broadcast_target_for_varbinds
    [product, [self, :varbinds]]
  end

  def broadcast_target_id_for_varbinds
    dom_id(product, dom_id(self, :varbinds))
  end

  def broadcast_locals_for_varbind(varbind)
    { product: product, variant: self, varbind: varbind }
  end
end


