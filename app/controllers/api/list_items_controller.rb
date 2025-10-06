class Api::ListItemsController < ApplicationController
  skip_before_action :require_authentication, raise: false
  before_action :set_list
  before_action :set_list_item, only: [:destroy]
  skip_before_action :verify_authenticity_token

  def index
    # Get list items for a specific client (from external client_id)
    external_client_id = params[:external_client_id]

    if external_client_id.present?
      client = resolve_client_by_external_id(external_client_id)
      if client
        @list_items = @list.list_items.where(client_id: client.id)
      else
        @list_items = ListItem.none
      end
    else
      @list_items = @list.list_items
    end

    respond_to do |format|
      format.json do
        render json: {
          items: @list_items.map { |item| serialize_list_item(item) },
          total_count: @list_items.count
        }
      end
    end
  end

  def create
    # Resolve client by external client_id via varbind
    client = resolve_client_by_external_id(params[:external_client_id]) if params[:external_client_id]
    return head :unprocessable_entity unless client

    # Resolve item (Product/Variant) by external IDs via varbind
    item = resolve_item_by_external_ids(params[:external_product_id], params[:external_variant_id])
    return head :unprocessable_entity unless item

    # Idempotent find-or-create by unique key (list_id, client_id, item_type, item_id)
    @list_item = @list.list_items.find_by(client_id: client.id, item_type: item.class.name, item_id: item.id)
    @list_item ||= @list.list_items.new(client_id: client.id, item: item, metadata: params[:metadata])

    respond_to do |format|
      if @list_item.persisted? || @list_item.save
        format.json do
          status_code = @list_item.previous_changes.present? ? :created : :ok
          render json: {
            item: serialize_list_item(@list_item),
            total_count: @list.list_items.where(client_id: client.id).count
          }, status: status_code
        end
      else
        format.json { render json: { errors: @list_item.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    client_id = @list_item.client_id
    @list_item.destroy!

    respond_to do |format|
      format.json do
        render json: {
          total_count: @list.list_items.where(client_id: client_id).count
        }
      end
    end
  end

  private

  # Resolve account for API requests by path param rather than session
  def current_account
    @current_account ||= Account.find(params[:account_id])
  end

  def set_list
    @list = current_account.lists.find(params[:list_id])
  end

  def set_list_item
    @list_item = @list.list_items.find(params[:id])
  end

  def resolve_client_by_external_id(external_client_id)
    # Find client by external ID via varbind scoped to account's Insale integrations
    return nil if external_client_id.blank?
    varbind = Varbind
      .where(record_type: 'Client', value: external_client_id)
      .where(varbindable: current_account.insales)
      .first
    return varbind.record if varbind

    # Auto-create Client and Varbind if not present
    insale = current_account.insales.first
    return nil unless insale

    client = current_account.clients.create!(name: "API Client #{external_client_id}")
    Varbind.create!(
      varbindable: insale,
      record: client,
      value: external_client_id
    )
    client
  end

  def resolve_item_by_external_ids(external_product_id, external_variant_id)
    # Try to find variant first by external variant_id
    if external_variant_id.present?
      varbind = Varbind
        .where(record_type: 'Variant', value: external_variant_id)
        .where(varbindable: current_account.insales)
        .first
      return varbind.record if varbind
    end

    # Fallback to product by external product_id
    if external_product_id.present?
      varbind = Varbind
        .where(record_type: 'Product', value: external_product_id)
        .where(varbindable: current_account.insales)
        .first
      return varbind.record if varbind
    end

    # Auto-create Product (and Variant if external_variant_id present)
    insale = current_account.insales.first
    return nil unless insale

    product = nil
    if external_product_id.present?
      product = current_account.products.create!(title: "API Product #{external_product_id}")
      Varbind.create!(
        varbindable: insale,
        record: product,
        value: external_product_id
      )
    end

    if external_variant_id.present?
      # Ensure product exists for variant; if not, create a container product
      product ||= current_account.products.create!(title: "API Product #{external_product_id}")
      variant = product.variants.create!
      Varbind.create!(
        varbindable: insale,
        record: variant,
        value: external_variant_id
      )
      return variant
    end

    product
  end

  def serialize_list_item(list_item)
    {
      id: list_item.id,
      item_id: list_item.item_id,
      item_type: list_item.item_type,
      metadata: list_item.metadata || {},
      created_at: list_item.created_at.iso8601
    }
  end
end
