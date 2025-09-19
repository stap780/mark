# Insale < ApplicationRecord
class Insale < ApplicationRecord
  belongs_to :account

  validates :api_link, presence: true
  validates :api_key, presence: true
  validates :api_password, presence: true

  # Keep exactly one record per account
  validates :account_id, uniqueness: true
 
  include ActionView::RecordIdentifier
  # Turbo Streams callbacks, scoped per account
  after_create_commit { broadcast_append_to [account, "insales"], target: "insales" }
  after_update_commit { broadcast_replace_to [account, "insales"], target:  dom_id(self) }
  after_destroy_commit { broadcast_remove_to [account, "insales"], target: dom_id(self) }

  # For ransack compatibility in case we add search later
  def self.ransackable_attributes(_auth_object = nil)
    attribute_names
  end

  # Initialize InSales API client for this account
  # If no record given, default to current account's config
  def self.api_init(record = nil)
    rec = record || Current.account&.insales&.first
    return false unless rec

    InsalesApi::App.api_key = rec.api_key
    InsalesApi::App.configure_api(rec.api_link, rec.api_password)
  end

  # Check API works using the current account's Insale record
  # Returns [true, ""] or [false, messages]
  def self.api_work?
    rec = Current.account&.insales&.first
    return [false, ["No Insale configuration for this account"]] unless rec

    api_init(rec)
    message = []
    begin
      account = InsalesApi::Account.find
    rescue SocketError
      message << "SocketError Check Key,Password,Domain"
    rescue ActiveResource::ResourceNotFound
      message << "not_found 404"
    rescue ActiveResource::ResourceConflict, ActiveResource::ResourceInvalid
      message << "ActiveResource::ResourceConflict, ActiveResource::ResourceInvalid"
    rescue ActiveResource::UnauthorizedAccess
      message << "Failed.  Response code = 401.  Response message = Unauthorized"
    rescue ActiveResource::ForbiddenAccess
      message << "Failed.  Response code = 403.  Response message = Forbidden."
    rescue StandardError => e
      message << "StandardError #{e}"
    else
      account
    end
    message.size.positive? ? [false, message] : [true, ""]
  end

  # Add webhook for orders/create for the current account
  # If no explicit address is provided, use the account's configured api_link
  # (caller is responsible for ensuring api_link contains a full URL if needed)
  def self.add_order_webhook(address: nil)
    rec = Current.account&.insales&.first
    return [false, ["No Insale configuration for this account"]] unless rec

    return [false, ["API not working"]] unless api_work?

    webh_list = InsalesApi::Webhook.all
    target_address = address || rec.api_link
    check_present = webh_list.any? { |w| w.topic == "orders/create" && w.address == target_address }

    if check_present
      message = "Webhook already exists. OK"
      return [true, message]
    end

    data_webhook_order_create = {
      address: target_address,
      topic: "orders/create",
      format_type: "json"
    }

    message = []
    webhook_order_create = InsalesApi::Webhook.new(webhook: data_webhook_order_create)
    begin
      webhook_order_create.save
    rescue SocketError
      message << "SocketError Check Key,Password,Domain"
    rescue ActiveResource::ResourceNotFound
      message << "not_found 404"
    rescue ActiveResource::ResourceConflict, ActiveResource::ResourceInvalid
      message << "ActiveResource::ResourceConflict, ActiveResource::ResourceInvalid"
    rescue ActiveResource::UnauthorizedAccess
      message << "Failed.  Response code = 401.  Response message = Unauthorized"
    rescue ActiveResource::ForbiddenAccess
      message << "Failed.  Response code = 403.  Response message = Forbidden."
    rescue StandardError => e
      message << "StandardError #{e}"
    else
      webhook_order_create
    end

    message.size.positive? ? [false, message] : [true, ""]
  end
end
