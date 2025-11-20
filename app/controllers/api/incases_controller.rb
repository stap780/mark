class Api::IncasesController < ApplicationController
  skip_before_action :require_authentication, raise: false
  skip_before_action :verify_authenticity_token

  def create
    account = Account.find(params[:account_id])
    webform = account.webforms.find(params.require(:webform_id))
    render json: { error: 'webform inactive' }, status: :unprocessable_entity and return unless webform.status_active?

    client = resolve_client!(account, params[:client])

    # Проверяем существующую заявку по number для всех типов форм
    if params[:number].present?
      incase = account.incases.find_by(number: params[:number], webform: webform)
      
      if incase
        # Обновляем существующую заявку: удаляем старые items и создаем новые
        incase.items.destroy_all
        incase.update!(client: client) if client != incase.client
      else
        # Создаем новую заявку с number
        incase = account.incases.create!(webform: webform, client: client, status: 'new', number: params[:number])
      end
    else
      # Если number не передан, создаем новую заявку без number
      incase = account.incases.create!(webform: webform, client: client, status: 'new')
    end

    items = Array(params[:items]).map do |it|
      resolve_item!(incase, account, it)
    end

    render json: { incase: { id: incase.id, status: incase.status, webform_id: webform.id, client_id: client.id } }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not found' }, status: :not_found
  end

  private

  def resolve_client!(account, client_params)
    return Client.find(client_params[:id]) if client_params && client_params[:id].present?
    email = client_params&.dig(:email)
    phone = client_params&.dig(:phone)
    client = account.clients.where('email = ? OR phone = ?', email, phone).first
    # Используем email или phone как fallback для name, если name пустой
    name = client_params[:name].presence || email.presence || phone.presence || "Client"
    client_attrs = { name: name, surname: client_params[:surname], email: email, phone: phone }
    client_attrs[:ya_client] = client_params[:ya_client_id] if client_params[:ya_client_id].present?
    client ||= account.clients.create!(client_attrs)
    # Обновляем ya_client если он изменился
    if client_params[:ya_client_id].present? && client.ya_client != client_params[:ya_client_id]
      client.update!(ya_client: client_params[:ya_client_id])
    end
    client
  end

  def resolve_item!(incase, account, item_params)
    # item_params содержит: type: "Variant", id: external_variant_id, quantity, price
    external_variant_id = item_params[:id].to_s
    quantity = item_params[:quantity] || 1
    price = item_params[:price] || 0

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
          record_type: "Product",
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
          record_type: "Variant",
          value: external_variant_id
        )
      end
    end

    # Если variant найден, убеждаемся что varbind'ы созданы для product и variant
    if variant && insale
      product = variant.product
      
      # Создаем varbind для product, если передан product_id и varbind еще не существует
      if item_params[:product_id].present?
        Varbind.find_or_create_by!(
          record: product,
          varbindable: insale,
          record_type: "Product",
          value: item_params[:product_id].to_s
        )
      end
      
      # Создаем varbind для variant, если передан external_variant_id и varbind еще не существует
      if external_variant_id.present?
        Varbind.find_or_create_by!(
          record: variant,
          varbindable: insale,
          record_type: "Variant",
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