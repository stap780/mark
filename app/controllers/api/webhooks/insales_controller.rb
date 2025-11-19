class Api::Webhooks::InsalesController < ApplicationController
  skip_before_action :require_authentication, raise: false
  skip_before_action :verify_authenticity_token

  def order
    account = Account.find(params[:account_id])
    return head :unprocessable_entity unless valid_signature?(account)

    webform = account.webforms.find_by(kind: 'order', status: 'active')
    return render json: { error: 'order webform not active' }, status: :unprocessable_entity unless webform

    payload = request.request_parameters.deep_symbolize_keys
    client = resolve_client_from_order!(account, payload[:client])

    incase = account.incases.create!(webform: webform, client: client, status: 'new')
    Array(payload[:items]).each do |it|
      resolve_item!(incase, account, it)
    end

    head :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def valid_signature?(account)
    # TODO: verify HMAC from Insales headers
    true
  end

  def resolve_client_from_order!(account, c)
    return account.clients.find(c[:id]) if c && c[:id].present?
    email = c&.dig(:email)
    phone = c&.dig(:phone)
    account.clients.where('email = ? OR phone = ?', email, phone).first || account.clients.create!(name: c[:name], surname: c[:surname], email: email, phone: phone)
  end

  def resolve_item!(incase, account, item_params)
    # item_params содержит: variant_id (external), quantity, price
    external_variant_id = item_params[:variant_id].to_s
    quantity = item_params[:quantity] || 1
    price = item_params[:price]

    # Находим variant в нашей БД по external_id через Varbind
    insale = account.insales.first
    variant = nil
    
    if insale && external_variant_id.present?
      varbind = Varbind.find_by(
        varbindable: insale,
        record_type: "Variant",
        value: external_variant_id
      )
      variant = varbind&.record
    end

    # Если variant не найден, создаем его
    unless variant
      # Пытаемся найти product по external_product_id, если он есть
      product = nil
      if item_params[:product_id].present?
        product_varbind = Varbind.find_by(
          varbindable: insale,
          record_type: "Product",
          value: item_params[:product_id].to_s
        )
        product = product_varbind&.record
      end

      # Если product не найден, создаем новый
      product ||= account.products.create!(title: "API Product #{item_params[:product_id] || 'Unknown'}")
      
      # Создаем varbind для product, если его еще нет
      if insale && item_params[:product_id].present?
        Varbind.find_or_create_by!(
          record: product,
          varbindable: insale,
          value: item_params[:product_id].to_s
        )
      end

      # Создаем variant
      variant = product.variants.create!
      
      # Создаем varbind для variant
      if insale && external_variant_id.present?
        Varbind.find_or_create_by!(
          record: variant,
          varbindable: insale,
          value: external_variant_id
        )
      end
    end

    # Создаем Item напрямую для incase
    incase.items.create!(
      product_id: variant.product_id,
      variant_id: variant.id,
      quantity: quantity,
      price: price
    )
  end
end


