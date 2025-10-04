json.extract! client, :id, :account_id, :name, :surname, :email, :phone, :clientid, :ya_client, :created_at, :updated_at
json.url client_url(client, format: :json)
