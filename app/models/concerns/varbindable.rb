module Varbindable
  extend ActiveSupport::Concern

  included do
    has_many :varbinds, as: :record, dependent: :destroy
  end

  # Each model that includes this concern must implement these methods
  def show_path
    raise NotImplementedError, "#{self.class} must implement #show_path"
  end

  def varbinds_path
    raise NotImplementedError, "#{self.class} must implement #varbinds_path"
  end

  def varbind_new_path
    raise NotImplementedError, "#{self.class} must implement #varbind_new_path"
  end

  def varbind_edit_path(varbind)
    raise NotImplementedError, "#{self.class} must implement #varbind_edit_path"
  end

  def varbind_path(varbind)
    raise NotImplementedError, "#{self.class} must implement #varbind_path"
  end

  def broadcast_target_for_varbinds
    raise NotImplementedError, "#{self.class} must implement #broadcast_target_for_varbinds"
  end

  def broadcast_target_id_for_varbinds
    raise NotImplementedError, "#{self.class} must implement #broadcast_target_id_for_varbinds"
  end

  def broadcast_locals_for_varbind(varbind)
    raise NotImplementedError, "#{self.class} must implement #broadcast_locals_for_varbind"
  end
end
