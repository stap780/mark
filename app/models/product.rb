class Product < ApplicationRecord
  include ActionView::RecordIdentifier
  include Varbindable

  belongs_to :account
  has_many :variants, dependent: :destroy
  has_many :swatch_group_products
  has_many :swatch_groups, through: :swatch_group_products

      # Varbindable implementation
      def show_path
        Rails.application.routes.url_helpers.account_product_path(
          account, self
        )
      end

      def varbinds_path
        Rails.application.routes.url_helpers.account_product_varbinds_path(
          account, self
        )
      end

      def varbind_new_path
        Rails.application.routes.url_helpers.new_account_product_varbind_path(
          account, self
        )
      end

      def varbind_edit_path(varbind)
        Rails.application.routes.url_helpers.edit_account_product_varbind_path(
          account, self, varbind
        )
      end

  def varbind_path(varbind)
    Rails.application.routes.url_helpers.account_product_varbind_path(
      account, self, varbind
    )
  end

  def broadcast_target_for_varbinds
    [self, :varbinds]
  end

  def broadcast_target_id_for_varbinds
    dom_id(self, :varbinds)
  end

  def broadcast_locals_for_varbind(varbind)
    { product: self, varbind: varbind }
  end

  accepts_nested_attributes_for :variants, allow_destroy: true
 
  before_destroy :ensure_not_used_in_swatch_groups
 
  private
 
  def ensure_not_used_in_swatch_groups
    return unless swatch_group_products.exists?
 
    errors.add(:base, 'Cannot delete product while assigned to a swatch group')
    throw(:abort)
  end
  
end
