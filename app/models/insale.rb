# Insale < ApplicationRecord
class Insale < ApplicationRecord
  include AccountScoped
  belongs_to :account

  has_one_attached :swatch_file
  has_one_attached :list_file
  has_one_attached :webform_file

  validates :api_link, presence: true
  validates :api_key, presence: true
  validates :api_password, presence: true

  # Keep exactly one record per account
  validates :account_id, uniqueness: true
 
  include ActionView::RecordIdentifier
  # Turbo Streams callbacks, scoped per account
  # after_create_commit do
  #   # Устанавливаем контекст аккаунта для route helpers в partial
  #   Account.current = account
  #   broadcast_append_to [account, "insales"], 
  #                      target: "insales",
  #                      partial: "insales/insale",
  #                      locals: { insale: self, current_account: account }
  # end
  # not use update commit with broadcast becuse it fire error in solid_queue with update nil account_id record
  # after_update_commit { broadcast_replace_to [account, "insales"], target:  dom_id(self) }
  after_destroy_commit { broadcast_remove_to [account, "insales"], target: dom_id(self) }

  # For ransack compatibility in case we add search later
  def self.ransackable_attributes(_auth_object = nil)
    attribute_names
  end

  def swatch_s3_url
    "https://s3.timeweb.cloud/#{self.swatch_file.service.bucket.name}/#{self.swatch_file.blob.key}"
  end

  def webform_s3_url
    "https://s3.timeweb.cloud/#{self.webform_file.service.bucket.name}/#{self.webform_file.blob.key}"
  end

  # Initialize InSales API client for this account
  # If no record given, default to current account's config
  def api_init
    InsalesApi::App.api_key = self.api_key
    InsalesApi::App.configure_api(self.api_link, self.api_password)
  end

  # Check API works using the current account's Insale record
  # Returns [true, ""] or [false, messages]
  def api_work?
    rec = account.insales&.first
    return [false, ["No Insale configuration for this account"]] unless rec

    rec.api_init
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
  def add_order_webhook(address: nil)
    return [false, ["API not working"]] unless api_work?

    webh_list = InsalesApi::Webhook.all
    target_address = address || "https://app.teletri.ru/api/accounts/#{account.id}/incases/insales_order"
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

  # Ask Insales API to create a marketplace feed and save its URL to product_xml
  # @param account [Account, nil] Optional account to use. If not provided, uses Current.account
  def self.create_xml(account: nil)
    target_account = account || Current.account
    rec = target_account&.insales&.first
    return [false, ["No Insale configuration for this account"]] unless rec

    rec.api_init

    begin
      collection_ids = InsalesApi::Collection.find(:all).map(&:id)
      property_id = InsalesApi::Property.first.id
      data = {
        marketplace: {
          "name": "YM mark #{Time.now}",
          "type": "Marketplace::ModelYandexMarket",
          "shop_name": "YM myappda",
          "shop_company": "YM myappda",
          "description_type": 1,
          "vendor_id": property_id,
          "adult": false,
          "delivery": true,
          "delivery_new_style": false,
          "pickup": false,
          "store": false,
          "page_encoding": "utf-8",
          "image_style": "compact",
          "model_type": "name",
          "collection_ids": collection_ids,
          "use_variants": true,
          "variants_action": "all"
        }
      }

      marketplace = InsalesApi::Marketplace.new(data)
      marketplace.save

      url = marketplace.try(:url) || marketplace.try(:feed_url)
      return [false, ["Insales API did not return a feed URL"]] unless url.present?

      rec.update(product_xml: url)
      [true, url]
    rescue SocketError
      [false, ["SocketError Check Key,Password,Domain"]]
    rescue ActiveResource::ResourceNotFound
      [false, ["not_found 404"]]
    rescue ActiveResource::ResourceConflict, ActiveResource::ResourceInvalid
      [false, ["ActiveResource::ResourceConflict, ActiveResource::ResourceInvalid"]]
    rescue ActiveResource::UnauthorizedAccess
      [false, ["Failed.  Response code = 401.  Response message = Unauthorized"]]
    rescue ActiveResource::ForbiddenAccess
      [false, ["Failed.  Response code = 403.  Response message = Forbidden."]]
    rescue ActiveResource::ClientError
      [false, ["ActiveResource::ClientError - Response code = 423. Response message = Locked"]]
    rescue StandardError => e
      Rails.logger.error("Insale.create_xml error: #{e.class}: #{e.message}")
      [false, ["StandardError #{e}"]]
    end
  end
  
end
