namespace :lists do
  desc "Backfill Favorites list items for a client. Usage: rake lists:backfill_favorites ACCOUNT_ID=1 CLIENT_ID=42 ENTRIES_JSON=path/to/entries.json"
  task backfill_favorites: :environment do
    account_id = ENV["ACCOUNT_ID"]
    client_id  = ENV["CLIENT_ID"]
    entries_json = ENV["ENTRIES_JSON"]

    abort "ACCOUNT_ID is required" unless account_id.present?
    abort "CLIENT_ID is required" unless client_id.present?

    entries = []
    if entries_json.present?
      begin
        entries = JSON.parse(File.read(entries_json), symbolize_names: true)
      rescue => e
        abort "Failed to read ENTRIES_JSON: #{e.message}"
      end
    else
      abort "ENTRIES_JSON is required (array of {item_type, item_id, metadata})"
    end

    list = BackfillFavoritesService.new(account_id: account_id, client_id: client_id, entries: entries, list_name: "Favorites").call
    puts "Backfilled #{list.list_items.count} items into list ##{list.id} (#{list.name})"
  end
end


