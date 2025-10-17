class ListItemsJsonGeneratorService
  def initialize(account_id, external_client_id, client_id)
    @account = Account.find(account_id)
    @external_client_id = external_client_id
    @client_id = client_id
    @file_name = "list_#{@account.id}_client_#{@external_client_id}_list_items.json"
  end

  def call
    insale = @account.insales.first
    return unless insale

    client = @account.clients.find(@client_id)
    return unless client

    payload = build_payload(client)

    io = StringIO.new(JSON.pretty_generate(payload))

    if client.list_items_file.attached?
      client.list_items_file.purge
    end

    if ActiveStorage::Blob.unattached.any?
      ActiveStorage::Blob.unattached.find_each(&:purge)
    end

    unless client.list_items_file.attached?
      client.list_items_file.attach(
        io: io,
        filename: @file_name,
        key: s3_file_key,
        content_type: "application/json"
      )
    end
  end

  private

  def build_payload(client)
    lists = @account.lists.order(:id)
    items_by_list = lists.map do |list|
      items = list.list_items.where(client_id: client.id)
      serialized = items.map { |li| serialize_item(li) }.compact
      { id: list.id, name: list.name, icon_style: list.icon_style, icon_color: list.icon_color, items: serialized }
    end
    {
      account_id: @account.id,
      client_external_id: @external_client_id,
      generated_at: Time.current.iso8601,
      lists: items_by_list
    }
  end

  def serialize_item(list_item)
    insale = @account.insales.first

    external_value = list_item.item.varbinds.find_by(varbindable: insale)&.value
    # here list_item.item_type is a Product
    {
      item_type: list_item.item_type,
      external_item_id: external_value,
      created_at: list_item.created_at.iso8601,
      item_link: "/product_by_id/#{external_value}"
      item_image: list_item.item.variants&.first&.image_link,
      item_price: list_item.item.variants&.first&.price
    }
  end

  def s3_file_key
    "lists/#{@file_name}"
  end

end