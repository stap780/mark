json.extract! list_item, :id, :list_id, :item_id, :item_type, :created_at, :updated_at
json.list do
  json.id list_item.list_id
  json.name list_item.list.name
  json.owner_type list_item.list.owner_type
  json.owner_id list_item.list.owner_id
end
json.item do
  json.type list_item.item_type
  json.id list_item.item_id
end
