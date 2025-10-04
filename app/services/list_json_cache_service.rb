class ListJsonCacheService
  def initialize(account_id:, owner_type:, owner_id:)
    @account = Account.find(account_id)
    @owner_type = owner_type
    @owner_id = owner_id
  end

  def call
    owner = @owner_type.constantize.find(@owner_id)
    lists = @account.lists.where(owner: owner).includes(:list_items)

    payload = lists.map do |list|
      {
        list_id: list.id,
        name: list.name,
        items: list.list_items.map { |li| item_hash(li) }
      }
    end

    # Persist to public cache path: lists/<account_id>/clients/<client_id>.json
    dir = Rails.root.join('public', 'lists', @account.id.to_s, owner_directory_segment)
    FileUtils.mkdir_p(dir)
    path = dir.join(file_name_for(owner))
    File.write(path, JSON.pretty_generate(payload))
    payload
  end

  private

  def item_hash(list_item)
    {
      item_type: list_item.item_type,
      item_id: list_item.item_id,
      metadata: list_item.metadata
    }
  end

  def owner_directory_segment
    case @owner_type
    when 'Client' then 'clients'
    else @owner_type.tableize
    end
  end

  def file_name_for(owner)
    case @owner_type
    when 'Client' then "#{owner.id}.json"
    else "#{owner.id}.json"
    end
  end
end


