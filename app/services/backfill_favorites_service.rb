class BackfillFavoritesService
  # entries: array of hashes [{ item_type: "Product", item_id: 123, metadata: {...} }, ...]
  def initialize(account_id:, client_id:, entries:, list_name: "Favorites")
    @account = Account.find(account_id)
    @client  = @account.clients.find(client_id)
    @entries = entries
    @list_name = list_name
  end

  def call
    list = @account.lists.where(owner: @client, name: @list_name).first_or_create!
    @entries.each do |e|
      list.list_items.where(item_type: e[:item_type], item_id: e[:item_id]).first_or_create!(metadata: e[:metadata])
    end
    list
  end
end


