class SwatchJsonGeneratorService
  def initialize(account_id)
    @account = Account.find(account_id)
  end

  def call
    groups = @account.swatch_groups.includes(swatch_group_products: :product)

    # Build offer lookup from product_xml feed: offer id -> { image, url }
    offer_lookup = build_offer_lookup_from_product_xml
    # Build entries like in your example: one entry per group item (product_id = offer id),
    # and the swatches array lists all items in the group as similar_id entries
    payload = groups.flat_map do |g|
      items = g.swatch_group_products.ordered
      items.map do |base|
        {
          swatch_id: g.id,
          product_id: base.swatch_value,
          name: g.name,
          option_name: g.option_name,
          status: g.status,
          product_page_style: g.product_page_style,
          collection_page_style: g.collection_page_style,
          swatch_image_source: g.swatch_image_source,
          swatches: items.map do |sgp|
            # offer_id = find_offer_id_for_product(sgp.product) || sgp.swatch_value
            # offer = offer_lookup[offer_id] || {}
            offer = offer_lookup[sgp.swatch_value] || {}
            {
              similar_id: sgp.swatch_value,
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

    # Write one JSON per account id (not per user): /swatch_groups/:account_id.json
    # dir = Rails.root.join('public', 'swatch_groups')
    # FileUtils.mkdir_p(dir)
    # path = dir.join("#{@account.id}.json")
    # File.delete(path) if File.exist?(path)
    # File.write(path, JSON.pretty_generate(payload))
    # Rails.logger.info("Generated swatch JSON for account #{@account.id}: #{payload.size} groups → files per user in /public/swatch_groups/")

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
    end

    payload
  end

  private

  def build_offer_lookup_from_product_xml
    rec = @account.insales.first
    return {} unless rec&.product_xml.present?

    xml_content = read_product_xml_content(rec.product_xml)
    return {} if xml_content.blank?

    begin
      require 'nokogiri'
      doc = Nokogiri::XML(xml_content)
      lookup = {}
      doc.xpath('//offer').each do |offer|
        offer_id = offer['id'] || offer.at('id')&.text
        next if offer_id.blank?
        pictures = offer.xpath('picture').map { |p| p.text }.compact.uniq
        url = offer.at('url')&.text
        entry = {}
        entry[:images] = pictures if pictures.any?
        entry[:url] = url if url.present?
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
        require "open-uri"
        URI.parse(link).open(read_timeout: 10).read
      rescue StandardError => e
        Rails.logger.error("Swatch JSON fetch error: #{e.message}")
        nil
      end
    end
  end

  # Determine the external offer_id for a given product by reading its variant varbinds
  # def find_offer_id_for_product(product)
  #   return nil unless product
  #   insale = @account.insales.first
  #   if insale
  #     vb = Varbind.joins(:variant)
  #                 .where(variants: { product_id: product.id })
  #                 .where(varbindable_type: 'Insale', varbindable_id: insale.id)
  #                 .order('varbinds.id DESC')
  #                 .first
  #     return vb.value if vb
  #   end

  #   vb_any = Varbind.joins(:variant)
  #                   .where(variants: { product_id: product.id })
  #                   .order('varbinds.id DESC')
  #                   .first
  #   vb_any&.value
  # end

  def s3_file_key
    if Rails.env.development?
      "swatches/dev_swatch_#{@account.id}.json"
    else
      "swatches/swatch_#{@account.id}.json"
    end
  end

end
