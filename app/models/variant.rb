class Variant < ApplicationRecord
  include ActionView::RecordIdentifier
  include Varbindable

  belongs_to :product
  has_many :list_items, as: :item

  before_destroy :check_list_items_dependency

  # Use Varbindable defaults

  def broadcast_target_for_varbinds
    [product, [self, :varbinds]]
  end

  def broadcast_target_id_for_varbinds
    dom_id(product, dom_id(self, :varbinds))
  end

  def broadcast_locals_for_varbind(varbind)
    { product: product, variant: self, varbind: varbind }
  end

  def self.ransackable_attributes(auth_object = nil)
    Variant.attribute_names
  end

  private

  def check_list_items_dependency
    return unless list_items.exists?

    errors.add(:base, "Cannot delete variant while it has items in Lists")
    throw(:abort)
  end

end


