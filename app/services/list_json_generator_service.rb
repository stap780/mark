class ListJsonGeneratorService
  def initialize(account_id)
    @account = Account.find(account_id)
  end

  def call
    # Attach via Active Storage to the account's Insale record swatch_file
    if (rec = @account.insales.first)
      io = StringIO.new(JSON.pretty_generate(build_payload))
      if rec.list_file.attached?
        rec.list_file.purge
      end
      rec.list_file.attach(
        io: io, 
        filename: "list_#{@account.id}.json",
        key: s3_file_key,
        content_type: "application/json"
      )
    end
  end

  private

  def build_payload
    lists = @account.lists.order(:id).select(:id, :name, :icon_style, :icon_color)
    { account_id: @account.id, generated_at: Time.current.iso8601, lists: lists.as_json }
  end

  def s3_file_key
    if Rails.env.development?
      "lists/dev_list_#{@account.id}.json"
    else
      "lists/list_#{@account.id}.json"
    end
  end

end