class Client < ApplicationRecord
  include ActionView::RecordIdentifier
  include Varbindable
  include AccountScoped

  belongs_to :account
  has_many :list_items, dependent: :destroy
  has_many :incases
  has_many :conversations, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_one_attached :list_items_file

  validates :name, presence: true

  # Метод для получения заявок со статусом in_progress и типом notify
  # Используется в IncaseNotifyGroupByClient для отправки уведомлений
  def incases_for_notify
    incases
      .joins(:webform)
      .where(status: 'in_progress')
      .where(webforms: { kind: 'notify' })
  end

  def broadcast_target_for_varbinds
    [account, [self, :varbinds]]
  end

  def broadcast_target_id_for_varbinds
    dom_id(account, dom_id(self, :varbinds))
  end

  def broadcast_locals_for_varbind(varbind)
    { client: self, varbind: varbind }
  end

  after_update_commit do
    broadcast_replace_to [dom_id(account), :clients],
                        target: dom_id(self, dom_id(account)),
                        partial: "clients/client",
                        locals: { client: self, current_account: account }
  end

  after_destroy_commit do
    broadcast_remove_to [dom_id(account), :clients], target: dom_id(self, dom_id(account))
  end


  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end


  def self.ransackable_associations(auth_object = nil)
    %w[list_items conversations]
  end

  def self.ransackable_scopes(auth_object = nil)
    %i[needs_contact waiting_for_response no_response_after_3]
  end

  # Scope для фильтрации "не отвечают 3+ дня" через Ransack
  scope :no_response_after_3, -> {
    no_response_after(3)
  }




  def insale_api_update
    ok, msg = account.insales.first.api_work?
    return [false, Array(msg)] unless ok
    
    rec = account.insales.first
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

  # Idempotent find-or-create list_item for this client
  # Usage: client.add_list_item(list_id: 6, item_type: "Product", item_id: 1982)
  def add_list_item(list_id:, item_type:, item_id:)
    list = account.lists.find(list_id)
    item = item_type.constantize.find(item_id)
    
    list_item = list.list_items.find_by(
      client_id: id,
      item_type: item.class.name,
      item_id: item.id
    )
    
    list_item ||= list.list_items.create!(
      client_id: id,
      item: item
    )
    
    list_item
  end

  def full_name
    [name, surname, email].join(' ')
  end

  # Методы для работы с перепиской
  def conversation
    account.conversations.find_by(client: self)
  end

  def conversation_status
    conv = conversation
    return 'no_contact' unless conv

    if conv.waiting_for_response?
      'waiting_response'
    elsif conv.last_incoming_at.present? && conv.last_incoming_at > 7.days.ago
      'active'
    elsif conv.last_outgoing_at.present? && (conv.last_incoming_at.nil? || conv.last_outgoing_at > conv.last_incoming_at)
      days_ago = ((Time.current - conv.last_outgoing_at) / 1.day).to_i
      if days_ago >= 3
        "no_response_#{days_ago}_days"
      else
        'waiting_response'
      end
    else
      'no_contact'
    end
  end

  def last_contact_days_ago
    conv = conversation
    return nil unless conv&.last_message_at
    ((Time.current - conv.last_message_at) / 1.day).to_i
  end

  def can_send_telegram?
    telegram_chat_id.present? || telegram_username.present? || phone.present?
  end

  def can_send_email?
    email.present?
  end

  def can_send_sms?
    phone.present?
  end

  # Scopes для фильтрации по статусу коммуникации
  scope :waiting_for_response, -> {
    joins(:conversations)
      .where(conversations: { status: 'active' })
      .where.not(conversations: { last_outgoing_at: nil })
      .where('conversations.last_incoming_at IS NULL OR conversations.last_outgoing_at > conversations.last_incoming_at')
  }

  scope :needs_contact, -> {
    left_joins(:conversations)
      .where(conversations: { id: nil })
  }

  scope :no_response_after, ->(days) {
    joins(:conversations)
      .where(conversations: { status: 'active' })
      .where.not(conversations: { last_outgoing_at: nil })
      .where('conversations.last_outgoing_at < ?', days.days.ago)
      .where('conversations.last_incoming_at IS NULL OR conversations.last_outgoing_at > conversations.last_incoming_at')
  }

end