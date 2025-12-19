class StockCheck
  def initialize(account)
    @account = account
    @insale = account.insales.first
  end

  def call
    return [false, "No Insale configuration for this account"] unless @insale
    return [false, "No product_xml URL configured"] unless @insale.product_xml.present?

    xml_url = @insale.product_xml
    temp_file = nil

    begin
      # Скачиваем XML файл во временную директорию
      temp_file = download_xml(xml_url)
      return [false, "Failed to download XML file"] unless temp_file

      # Парсим XML, обновляем варианты и заявки
      updated_variants_count, updated_incases_count = parse_and_update_variants(temp_file)

      [true, {
        variants_count: updated_variants_count,
        incases_count: updated_incases_count
      }]
    rescue => e
      Rails.logger.error("StockCheck error: #{e.class}: #{e.message}")
      Rails.logger.error("StockCheck backtrace: #{e.backtrace.join('\n')}")
      [false, "Error: #{e.message}"]
    ensure
      # Удаляем временный файл
      if temp_file && File.exist?(temp_file)
        File.delete(temp_file)
      end
    end
  end

  private

  def download_xml(url)
    temp_file = Tempfile.new(['stock_check', '.xml'])
    temp_file.binmode
    
    URI.parse(url).open(read_timeout: 30) do |remote_file|
      temp_file.write(remote_file.read)
    end
    
    temp_file.rewind
    file_path = temp_file.path
    temp_file.close
    file_path
  rescue => e
    Rails.logger.error("StockCheck download error: #{e.message}")
    temp_file&.close
    temp_file&.unlink
    nil
  end

  def parse_and_update_variants(xml_file_path)
    doc = Nokogiri::XML(File.read(xml_file_path))
    updated_variants = []

    # Шаг 1: Обновляем quantity для всех вариантов
    doc.xpath('//offer').each do |offer_node|
      offer_id = offer_node['id'] || offer_node.at('id')&.text
      next unless offer_id.present?

      # Находим variant по external ID через varbind
      variant = find_variant_by_external_id(offer_id.to_s)
      next unless variant

      # Если quantity = 0, меняем на 1
      if variant.quantity.to_i == 0
        variant.update_column(:quantity, 1)
        updated_variants << variant
        Rails.logger.info("StockCheck: Updated variant ##{variant.id} (external_id: #{offer_id}) quantity from 0 to 1")
      end
    end

    return [0, 0] if updated_variants.empty?

    # Шаг 2: Находим все заявки с обновленными вариантами (только со статусом 'new')
    variant_ids = updated_variants.map(&:id)
    incases = @account.incases.joins(items: :variant)
                     .where(variants: { id: variant_ids })
                     .joins(:webform)
                     .where(webforms: { kind: 'notify' })
                     .where(status: 'new')
                     .distinct

    return [updated_variants.count, 0] if incases.empty?

    # Шаг 3: Обновляем статус заявок на "in_progress"
    incase_ids = incases.pluck(:id)
    @account.incases.where(id: incase_ids).update_all(status: 'in_progress')
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

