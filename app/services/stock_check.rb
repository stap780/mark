# frozen_string_literal: true

class StockCheck
  def initialize(account)
    @account = account
    @insale = account.insales.first
  end

  def call
    return [false, "No Insale configuration for this account"] unless @insale
    return [false, "No product_xml_offers data - run sync first"] unless @insale.product_xml_offers.exists?

    offer_ids = @insale.product_xml_offers.pluck(:offer_id)
    updated_variants_count, updated_incases_count = update_variants_and_incases(offer_ids)

    [true, {
      variants_count: updated_variants_count,
      incases_count: updated_incases_count
    }]
  rescue => e
    Rails.logger.error("StockCheck error: #{e.class}: #{e.message}")
    Rails.logger.error("StockCheck backtrace: #{e.backtrace.join("\n")}")
    [false, "Error: #{e.message}"]
  end

  private

  def update_variants_and_incases(offer_ids)
    updated_variants = []

    offer_ids.each do |offer_id|
      variant = find_variant_by_external_id(offer_id.to_s)
      next unless variant

      if variant.quantity.to_i == 0
        variant.update_column(:quantity, 1)
        updated_variants << variant
        Rails.logger.info("StockCheck: Updated variant ##{variant.id} (external_id: #{offer_id}) quantity from 0 to 1")
      end
    end

    return [0, 0] if updated_variants.empty?

    variant_ids = updated_variants.map(&:id)
    incases = @account.incases.joins(items: :variant)
                     .where(variants: { id: variant_ids })
                     .joins(:webform)
                     .where(webforms: { kind: "notify" })
                     .where(status: "new")
                     .distinct

    return [updated_variants.count, 0] if incases.empty?

    incase_ids = incases.pluck(:id)
    @account.incases.where(id: incase_ids).update_all(status: "in_progress")
    Rails.logger.info("StockCheck: Updated #{incase_ids.count} incases to 'in_progress' status")

    [updated_variants.count, incase_ids.count]
  end

  def find_variant_by_external_id(external_id)
    return nil unless @insale

    varbind = Varbind.find_by(
      varbindable: @insale,
      record_type: "Variant",
      value: external_id.to_s
    )

    varbind&.record
  end
end
