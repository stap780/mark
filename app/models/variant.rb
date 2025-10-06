class Variant < ApplicationRecord
  include ActionView::RecordIdentifier
  include Varbindable

  belongs_to :product

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
end


