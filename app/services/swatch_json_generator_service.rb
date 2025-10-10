class SwatchJsonGeneratorService
  require "nokogiri"
  require "open-uri"

  def initialize(account_id)
    @account = Account.find(account_id)
  end

  def call
    begin
      Rails.logger.info "Starting swatch JSON generation for account #{@account.id}"

      groups = @account.swatch_groups.includes(swatch_group_products: :product)

      # Build offer lookup from product_xml feed: offer id -> { image, url }
      offer_lookup = build_offer_lookup_from_product_xml

      # Build entries like in your example: one entry per group item (product_id = offer id),
      # and the swatches array lists all items in the group as similar_id entries
      payload = groups.flat_map do |g|
        items = g.swatch_group_products.ordered
        items.map do |base|
          # Get group_id from product varbinds
          group_id = base.product&.varbinds&.find_by(varbindable_type: 'Insale')&.value

          {
            swatch_id: g.id,
            product_id: group_id || base.swatch_value,
            name: g.name,
            option_name: g.option_name,
            status: g.status,
            product_page_style: g.product_page_style,
            collection_page_style: g.collection_page_style,
            swatch_image_source: g.swatch_image_source,
            css_class_product: g.css_class_product,
            css_class_preview: g.css_class_preview,
            swatches: items.map do |sgp|
              # Get offer_id from product varbinds (not variants)
              offer_id = sgp.product&.varbinds&.find_by(varbindable_type: 'Insale')&.value

              # Use offer_id to lookup in XML data
              offer = offer_lookup[offer_id] || {}
              # puts "offer => #{offer}"
              {
                similar_id: offer_id || sgp.swatch_value,
                title: sgp.title,
                images: offer[:images],
                link: offer[:url],
                color: sgp.color,
                label: sgp.swatch_label,
                picture: sgp.image_s3_url
              }
            end
          }
        end
      end

      # Attach via Active Storage to the account's Insale record swatch_file
      if (rec = @account.insales.first)
        io = StringIO.new(JSON.pretty_generate(payload))
        if rec.swatch_file.attached?
          rec.swatch_file.purge
        end
        rec.swatch_file.attach(
          io: io, 
          filename: "swatch_#{@account.id}.json",
          key: s3_file_key,
          content_type: "application/json"
        )
        Rails.logger.info "Swatch JSON file attached to S3 for account #{@account.id}"
      else
        Rails.logger.warn "No Insale record found for account #{@account.id}"
      end

      Rails.logger.info "Swatch JSON generation completed for account #{@account.id}"
      payload
    rescue => e
      Rails.logger.error "Swatch JSON generation failed for account #{@account.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end

  private

  def build_offer_lookup_from_product_xml
    rec = @account.insales.first
    return {} unless rec&.product_xml.present?

    xml_content = read_product_xml_content(rec.product_xml)
    return {} if xml_content.blank?

    begin
      doc = Nokogiri::XML(xml_content)
      lookup = {}
      doc.xpath('//offer').each do |offer|
        offer_id = offer['id'] || offer.at('id')&.text
        group_id = offer['group_id'] || offer.at('group_id')&.text
        next if offer_id.blank?
        pictures = offer.xpath('picture').map { |p| p.text }.compact.uniq
        url = offer.at('url')&.text
        entry = {}
        entry[:images] = pictures if pictures.any?
        entry[:url] = url if url.present?
        entry[:group_id] = group_id if group_id.present?
        lookup[offer_id] = entry if entry.any?
      end
      lookup
    rescue StandardError => e
      Rails.logger.error("Swatch JSON image lookup parse error: #{e.message}")
      {}
    end
  end

  def read_product_xml_content(link)
    if link.start_with?('/')
      file_path = Rails.root.join("public", link.sub(%r{^/}, ""))
      return File.read(file_path) if File.exist?(file_path)
      return nil
    end

    if link =~ %r{^https?://}
      begin
        URI.parse(link).open(read_timeout: 10).read
      rescue StandardError => e
        Rails.logger.error("Swatch JSON fetch error: #{e.message}")
        nil
      end
    end
  end

  def s3_file_key
    if Rails.env.development?
      "swatches/dev_swatch_#{@account.id}.json"
    else
      "swatches/swatch_#{@account.id}.json"
    end
  end

end