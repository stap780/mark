class Variant < ApplicationRecord
  include ActionView::RecordIdentifier
  include Varbindable

  belongs_to :product
  has_many :list_items, as: :item
  has_many :varbinds, as: :record, dependent: :destroy
  has_many :items

  before_destroy :check_list_items_dependency
  before_destroy :check_items_dependency

  after_update_commit :check_back_in_stock

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

  def check_items_dependency
    return unless items.exists?

    errors.add(:base, "Cannot delete variant while it has items in Incases")
    throw(:abort)
  end

  def check_back_in_stock
    return unless quantity_changed?
    return unless quantity.to_i > 0
    return if quantity_was.to_i > 0

    # Находим все заявки с этим товаром
    incases = Incase.joins(items: :variant)
                   .where(variants: { id: id })
                   .joins(:webform)
                   .where(webforms: { kind: ['preorder', 'notify'] })
                   .where(status: ['new', 'in_progress'])
                   .distinct

    incases.find_each do |incase|
      Automation::Engine.call(
        account: incase.account,
        event: "variant.back_in_stock",
        object: self,
        context: {
          incase: incase,
          client: incase.client,
          webform: incase.webform,
          product: product
        }
      )
    end
  end
end


