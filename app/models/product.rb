class Product < ApplicationRecord
  include ActionView::RecordIdentifier
  include Varbindable

  belongs_to :account
  has_many :variants, dependent: :destroy
  accepts_nested_attributes_for :variants, allow_destroy: true
  has_many :swatch_group_products
  has_many :swatch_groups, through: :swatch_group_products

  before_destroy :ensure_not_used_in_swatch_groups

  validates :title, presence: true

  def broadcast_target_for_varbinds
    [self, :varbinds]
  end

  def broadcast_target_id_for_varbinds
    dom_id(self, :varbinds)
  end

  def broadcast_locals_for_varbind(varbind)
    { product: self, varbind: varbind }
  end

  def self.ransackable_attributes(auth_object = nil)
    Product.attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[variants]
  end


  def insale_api_update(integration: nil)
    rec = integration || account.insales.first
    return [false, ["No Insale configuration for this account"]] unless rec

    ok, msg = Insale.api_work?
    return [false, Array(msg)] unless ok

    # external id for this product in Insale stored in Varbind
    external_id = varbinds.find_by(varbindable: rec)&.value
    return [false, ["No Insale varbind value for product"]] if external_id.to_s.strip.blank?

    begin
      Insale.api_init(rec)
      # Try to fetch product by id from Insales API
      ins_product = InsalesApi::Product.find(external_id)
    rescue StandardError => e
      Rails.logger.error("Product#insale_api_update fetch error: #{e.class} #{e.message}")
      return [false, ["Fetch error: #{e.message}"]]
    end

    # Map product fields defensively
    new_title = ins_product.try(:title)
    images = Array(ins_product.try(:images))
    first_image_url = images&.first.try(:large_url) rescue nil

    self.title = new_title.presence || title
    save! if changed?

    # Extract first variant payload from Insales and resolve local Variant by varbind
    ins_variant = Array(ins_product.try(:variants)).first
    ext_variant_id = ins_variant.try(:id).to_s.presence

    # Find or create variant via varbind (scoped to integration)
    variant = nil
    if ext_variant_id
      vbind = Varbind.find_or_create_by!(varbindable: rec, record_type: "Variant", value: ext_variant_id)
      variant = vbind.record
    end
    variant ||= variants.first || variants.build

    update_attrs = {}
    update_attrs[:barcode]   = ins_variant.try(:barcode)
    update_attrs[:sku]       = ins_variant.try(:sku)
    update_attrs[:price]     = ins_variant.try(:price)
    update_attrs[:image_link]= ins_variant.try(:images)&.first.try(:large_url) || first_image_url
    variant.update!(update_attrs)

    [true, { product: self, variant: variant }]
  end

  private

  def ensure_not_used_in_swatch_groups
    return unless swatch_group_products.exists?

    errors.add(:base, "Cannot delete product while assigned to a swatch group")
    throw(:abort)
  end

end
