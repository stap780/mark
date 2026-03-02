# frozen_string_literal: true

class ProductXmlSync
  BATCH_SIZE = 1000

  def initialize(account)
    @account = account
    @insale = account.insales.first
  end

  def call
    return [false, "No Insale configuration for this account"] unless @insale
    return [false, "No product_xml URL configured"] unless @insale.product_xml.present?

    temp_file = nil

    begin
      temp_file = download_xml(@insale.product_xml)
      return [false, "Failed to download XML file"] unless temp_file

      count = parse_and_save(temp_file)
      [true, { offers_count: count }]
    rescue => e
      Rails.logger.error("ProductXmlSync error: #{e.class}: #{e.message}")
      Rails.logger.error("ProductXmlSync backtrace: #{e.backtrace.join("\n")}")
      [false, "Error: #{e.message}"]
    ensure
      if temp_file && File.exist?(temp_file)
        File.delete(temp_file)
      end
    end
  end

  private

  def download_xml(url)
    temp_file = Tempfile.new(["product_xml_sync", ".xml"])
    temp_file.binmode

    URI.parse(url).open(read_timeout: 60) do |remote_file|
      temp_file.write(remote_file.read)
    end

    temp_file.rewind
    path = temp_file.path
    temp_file.close
    path
  rescue => e
    Rails.logger.error("ProductXmlSync download error: #{e.message}")
    temp_file&.close
    temp_file&.unlink
    nil
  end

  def parse_and_save(xml_file_path)
    doc = Nokogiri::XML(File.read(xml_file_path))
    batch = []
    count = 0

    ProductXmlOffer.transaction do
      ProductXmlOffer.where(insale_id: @insale.id).delete_all

      doc.xpath("//offer").each do |node|
        offer_id = node["id"] || node.at("id")&.text
        next unless offer_id.present?

        model = node.at("model")&.text.to_s
        vendor_code = node.at("vendorCode")&.text.to_s
        picture = node.at("picture")&.text
        pictures = node.xpath("picture").map { |p| p.text }.compact.uniq
        group_id = node.at("group_id")&.text || node["group_id"]
        url = node.at("url")&.text
        price_text = node.at("price")&.text.to_s.strip
        price = price_text.present? ? price_text.to_d : nil

        batch << {
          insale_id: @insale.id,
          offer_id: offer_id,
          group_id: group_id,
          model: model,
          vendor_code: vendor_code,
          picture: picture,
          pictures: pictures,
          url: url,
          price: price,
          created_at: Time.current,
          updated_at: Time.current
        }

        if batch.size >= BATCH_SIZE
          ProductXmlOffer.insert_all(batch)
          count += batch.size
          batch = []
        end
      end

      if batch.any?
        ProductXmlOffer.insert_all(batch)
        count += batch.size
      end
    end

    count
  end
end
