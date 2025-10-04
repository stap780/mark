class Varbind < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :record, polymorphic: true
  belongs_to :varbindable, polymorphic: true
  
  validates :varbindable_id, presence: true
  validates :varbindable_type, presence: true
  validates :value, presence: true
  validates :value, uniqueness: { scope: [:varbindable_id, :varbindable_type, :record_type, :record_id], message: "combination of varbindable_type, varbindable_id, record_type, record_id, and value must be unique" }

  # Broadcast inline updates using Rails 8 polymorphic approach
  after_create_commit :broadcast_create
  after_update_commit :broadcast_update  
  after_destroy_commit :broadcast_destroy

  private

  def broadcast_create
    broadcast_append_to broadcast_target,
                        target: broadcast_target_id,
                        partial: 'varbinds/varbind',
                        locals: broadcast_locals
    # Special case for Variant: also update the empty state
    broadcast_update_to broadcast_target, target: broadcast_target_id, html: "" if record.is_a?(Variant)
  end

  def broadcast_update
    broadcast_replace_to broadcast_target,
                         target: dom_id(record, dom_id(self)),
                         partial: 'varbinds/varbind',
                         locals: broadcast_locals
  end

  def broadcast_destroy
    broadcast_remove_to broadcast_target, target: dom_id(record, dom_id(self))
  end

  # Polymorphic broadcast configuration
  def broadcast_target
    record.broadcast_target_for_varbinds
  end

  def broadcast_target_id
    record.broadcast_target_id_for_varbinds
  end

  def broadcast_locals
    record.broadcast_locals_for_varbind(self)
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