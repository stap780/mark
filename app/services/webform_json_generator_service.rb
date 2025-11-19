class WebformJsonGeneratorService
  def initialize(account_id)
    @account = Account.find(account_id)
  end

  def call
    if (rec = @account.insales.first)
      io = StringIO.new(JSON.pretty_generate(build_payload))
      if rec.webform_file.attached?
        rec.webform_file.purge
      end
      rec.webform_file.attach(
        io: io,
        filename: "webform_#{@account.id}.json",
        key: s3_file_key,
        content_type: "application/json"
      )
    end
  end

  private

  def build_payload
    webforms = @account.webforms.where(status: 'active').order(:id)
    webforms_data = webforms.map do |webform|
      Webforms::BuildSchema.new(webform).call
    end

    {
      account_id: @account.id,
      generated_at: Time.current.iso8601,
      webforms: webforms_data
    }
  end

  def s3_file_key
    if Rails.env.development?
      "webforms/dev_webform_#{@account.id}.json"
    else
      "webforms/webform_#{@account.id}.json"
    end
  end
end

