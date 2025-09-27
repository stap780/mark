class Varbind < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :variant
  belongs_to :varbindable, polymorphic: true

  validates :varbindable_id, presence: true
  validates :varbindable_type, presence: true
  validates :value, presence: true
  validates :value, uniqueness: { scope: [:varbindable_id, :varbindable_type], message: "combination of varbindable_type, varbindable_id, and value must be unique" }

  # Broadcast inline updates like dizauto
  after_create_commit do
    broadcast_append_to [variant.product, [variant, :varbinds]],
                        target: dom_id(variant.product, dom_id(variant, :varbinds)),
                        partial: 'varbinds/varbind',
                        locals: { product: variant.product, variant: variant, varbind: self }
    broadcast_update_to [variant.product, [variant, :varbinds]], target: dom_id(variant.product, dom_id(variant, dom_id(Varbind.new))), html: ""
  end

  after_update_commit do
    broadcast_replace_to [variant.product, [variant, :varbinds]],
                         target: dom_id(variant.product, dom_id(variant, dom_id(self))),
                         partial: 'varbinds/varbind',
                         locals: { product: variant.product, variant: variant, varbind: self }
  end

  after_destroy_commit do
    broadcast_remove_to [variant.product, [variant, :varbinds]],
                        target: dom_id(variant.product, dom_id(variant, dom_id(self)))
  end

  def self.int_types
    [['insales','Insale']]
    # example if we have several integrations
    # Avito, Insale - name of model
    # [['avito','Avito'],['insales','Insale']]
    #
  end

  def self.int_ids
    return [] unless Insale.exists?

    Insale.all.map { |i| ["InSale #{i.id}", i.id] } # because we can have 2 insales integration with 2 different store

    # example if we have several integrations
    # avitos = Avito.all.map { |a| ["Avito #{a.id}", a.id] }
    # insales = Insale.all.map { |i| ["InSale #{i.id}", i.id] }
    # avitos + insales
    #
  end

end