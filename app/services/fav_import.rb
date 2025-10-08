# Imports favorites from a CSV available at `csv_url` into the given account.
# Expected headers (case-insensitive):
# clientid, name, surname, email, phone, insid, title
# - clientid -> Varbind on Client (value)
# - insid    -> Varbind on Product (value)
# Missing entities are auto-created with provided attributes.
# Use => FavImport.call(account: Account.find(2), csv_url: 'https://example.com/favorites.csv')
# FavImport.call(account: Account.find(5), csv_url: 'https://s3.twcstorage.ru/ae4cd7ee-b62e0601-19d6-483e-bbf1-416b386e5c23/clients_favorites_%20insales538988.csv')
# 
require "csv"
require "open-uri"

class FavImport
  def self.call(account:, csv_url:, list_name: "favorite", integration: nil)
    new(account: account, csv_url: csv_url, list_name: list_name, integration: integration).call
  end

  def initialize(account:, csv_url:, list_name:, integration: nil)
    @account = account
    @csv_url = csv_url
    @list_name = list_name.to_s
    # Prefer provided integration record (e.g., Insale) for varbinds; fallback to account
    @varbindable = integration || @account.insales.first || @account
  end

  def call
    ensure_list!
    io = URI.open(@csv_url)
    CSV.new(io, headers: true, header_converters: :symbol).each.with_index do |row, idx|
      break if idx >= 100
      import_row(row)
    end
    true
  end

  private

  def ensure_list!
    @list = @account.lists.find_or_create_by!(name: @list_name) do |lst|
      # Provide sensible defaults for new lists
      lst.icon_style = List::ICON_STYLES.keys.first
      lst.icon_color = '#e11d48'
    end
  end

  def import_row(row)
    clientid = safe_s(row[:clientid])
    name     = safe_s(row[:name])
    surname  = safe_s(row[:surname])
    email    = safe_s(row[:email])
    phone    = safe_s(row[:phone])
    insid    = safe_s(row[:insid])
    title    = safe_s(row[:title])

    return if clientid.blank? || insid.blank?

    Rails.logger.info("[FavImport] Processing row: clientid=#{clientid}, insid=#{insid}, title=#{title}")

    client = find_or_create_client(clientid: clientid, name: name, surname: surname, email: email, phone: phone)
    Rails.logger.info("[FavImport] Client: #{client.id} (#{client.name})")

    product = find_or_create_product(insid: insid, title: title)
    Rails.logger.info("[FavImport] Product: #{product.id} (#{product.title})")

    # Idempotent list item for Product
    list_item = ListItem.find_or_create_by!(list: @list, client: client, item: product)
    Rails.logger.info("[FavImport] ListItem created: #{list_item.id}")
  rescue => e
    Rails.logger.error("[FavImport] row error: #{e.class} #{e.message}; row=#{row.inspect}")
    Rails.logger.error("[FavImport] Backtrace: #{e.backtrace.first(5).join("\n")}")
  end

  def find_or_create_client(clientid:, name:, surname:, email:, phone:)
    # Lookup by varbind value
    Rails.logger.info("[FavImport] Looking for client varbind: varbindable=#{@varbindable.class}##{@varbindable.id}, record_type=Client, value=#{clientid}")
    bind = Varbind.find_by(varbindable: @varbindable, record_type: "Client", value: clientid)
    Rails.logger.info("[FavImport] Found varbind: #{bind.inspect}")
    client = bind&.record
    Rails.logger.info("[FavImport] Client from varbind: #{client.inspect}")
    return client if client

    client = @account.clients.create!(
      name: name.presence || [name, surname].reject(&:blank?).join(' ').presence || "Client #{clientid}",
      surname: surname.presence,
      email: email.presence,
      phone: phone.presence
    )
    Varbind.find_or_create_by!(record: client, varbindable: @varbindable, value: clientid)
    client
  end

  def find_or_create_product(insid:, title:)
    Rails.logger.info("[FavImport] Looking for product varbind: varbindable=#{@varbindable.class}##{@varbindable.id}, record_type=Product, value=#{insid}")
    bind = Varbind.find_by(varbindable: @varbindable, record_type: "Product", value: insid)
    Rails.logger.info("[FavImport] Found varbind: #{bind.inspect}")
    product = bind&.record
    Rails.logger.info("[FavImport] Product from varbind: #{product.inspect}")
    return product if product

    product = @account.products.create!(title: title.presence || "Product #{insid}")
    Varbind.find_or_create_by!(record: product, varbindable: @varbindable, value: insid)
    product
  end

  def safe_s(val)
    v = val.to_s.strip
    v == '' ? nil : v
  end
end