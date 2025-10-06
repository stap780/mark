class ListItemsJsonGeneratorService
  def initialize(account_id, external_client_id)
    @account = Account.find(account_id)
    @external_client_id = external_client_id
  end

  def call
    insale = @account.insales.first
    return unless insale

    client = resolve_client_by_external_id(@external_client_id)
    return unless client

    payload = build_payload(client)

    io = StringIO.new(JSON.pretty_generate(payload))
    if insale.client_list_items_file.attached?
      insale.client_list_items_file.purge
    end
    insale.client_list_items_file.attach(
      io: io,
      filename: "list_#{@account.id}_client_#{@external_client_id}_list_items.json",
      key: s3_file_key,
      content_type: "application/json"
    )
  end

  private

  def resolve_client_by_external_id(external_client_id)
    Varbind
      .where(record_type: 'Client', value: external_client_id)
      .where(varbindable: @account.insales)
      .first&.record
  end

  def build_payload(client)
    lists = @account.lists.order(:id)
    items_by_list = lists.map do |list|
      items = list.list_items.where(client_id: client.id)
      serialized = items.map { |li| serialize_item(li) }
      { id: list.id, name: list.name, items: serialized }
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
    {
      item_type: list_item.item_type,
      external_item_id: external_value,
      created_at: list_item.created_at.iso8601
    }
  end

  def s3_file_key
    "lists/list_#{@account.id}_client_#{@external_client_id}_list_items.json"
  end
end