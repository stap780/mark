class Client < ApplicationRecord
  include ActionView::RecordIdentifier
  include Varbindable
  include AccountScoped

  belongs_to :account
  has_many :list_items, dependent: :destroy
  has_one_attached :list_items_file

  validates :name, presence: true

  # Use Varbindable defaults

  def broadcast_target_for_varbinds
    [account, [self, :varbinds]]
  end

  def broadcast_target_id_for_varbinds
    dom_id(account, dom_id(self, :varbinds))
  end

  def broadcast_locals_for_varbind(varbind)
    { client: self, varbind: varbind }
  end

  # Hotwire broadcasts
  after_create_commit do
    broadcast_prepend_to [self.account, :clients],
                        target: [self.account, :clients],
                        partial: "clients/client",
                        locals: { client: self, current_account: self.account }
  end

  after_update_commit do
    broadcast_replace_to [self.account, :clients],
                        target: dom_id(self),
                        partial: "clients/client",
                        locals: { client: self, current_account: self.account }
  end

  after_destroy_commit do
    broadcast_remove_to [self.account, :clients], target: dom_id(self)
  end


  def self.ransackable_attributes(auth_object = nil)
    Client.attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[list_items]
  end


  def insale_api_update
    ok, msg = account.insales.first.api_work?
    return [false, Array(msg)] unless ok
    
    # external id for this client in Insale stored in Varbind
    external_id = varbinds.find_by(varbindable: rec)&.value
    return [false, ["No Insale varbind value for client"]] if external_id.to_s.strip.blank?

    begin
      account.insales.first.api_init
      # Try to fetch client by id from Insales API
      ins_client = InsalesApi::Client.find(external_id)
    rescue StandardError => e
      Rails.logger.error("Client#insale_api_update fetch error: #{e.class} #{e.message}")
      return [false, ["Fetch error: #{e.message}"]]
    end

    # Map client fields defensively
    new_name = ins_client.try(:name)
    new_surname = ins_client.try(:surname)
    new_email = ins_client.try(:email)
    new_phone = ins_client.try(:phone)
    self.name = new_name.presence || name
    self.surname = new_surname.presence || surname
    self.email = new_email.presence || email
    self.phone = new_phone.presence || phone
    save! if changed?
  end

end