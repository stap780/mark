module Varbindable
  extend ActiveSupport::Concern

  included do
    has_many :varbinds, as: :record, dependent: :destroy
  end

  # Default route helpers using polymorphic routing
  # def show_path
  #   case self
  #   when Client
  #     Rails.application.routes.url_helpers.account_client_path(account, self)
  #   when Product
  #     Rails.application.routes.url_helpers.account_product_path(account, self)
  #   when Variant
  #     Rails.application.routes.url_helpers.account_product_variant_path(product.account, product, self)
  #   else
  #     Rails.application.routes.url_helpers.polymorphic_path(polymorphic_stack(self))
  #   end
  # end
  def show_path
    Rails.application.routes.url_helpers.polymorphic_path(polymorphic_stack(self))
  end

  def varbinds_path
    Rails.application.routes.url_helpers.polymorphic_path(polymorphic_stack(self) + [:varbinds])
  end

  def varbind_new_path
    Rails.application.routes.url_helpers.polymorphic_path(polymorphic_stack(self) + [:varbind], action: :new)
  end

  def varbind_edit_path(varbind)
    Rails.application.routes.url_helpers.polymorphic_path(polymorphic_stack(self) + [varbind], action: :edit)
  end

  def varbind_path(varbind)
    Rails.application.routes.url_helpers.polymorphic_path(polymorphic_stack(self) + [varbind])
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

  private

  # Build the polymorphic stack like [account, parent, self]
  def polymorphic_stack(record)
    stack = []
    stack << account_for_varbinds(record)
    parent = parent_resource_for_varbinds(record)
    stack << parent if parent
    stack << record
    stack
  end

  def account_for_varbinds(record)
    if record.respond_to?(:account)
      record.account
    else
      # Variant has product → product.account
      record.product.account
    end
  end

  def parent_resource_for_varbinds(record)
    # Only Variant has a parent resource (Product)
    record.respond_to?(:product) ? record.product : nil
  end
end
