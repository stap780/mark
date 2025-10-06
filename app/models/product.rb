class Product < ApplicationRecord
  include ActionView::RecordIdentifier
  include Varbindable

  belongs_to :account
  has_many :variants, dependent: :destroy
  has_many :swatch_group_products
  has_many :swatch_groups, through: :swatch_group_products
  
  validates :title, presence: true

  # Use Varbindable defaults

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
