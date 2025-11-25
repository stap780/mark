class Api::IncasesController < ApplicationController
  skip_before_action :require_authentication, raise: false
  skip_before_action :verify_authenticity_token

  def create
    account = current_account || Account.find(params[:account_id])
    webform = account.webforms.find(params.require(:webform_id))
    render json: { error: 'webform inactive' }, status: :unprocessable_entity and return unless webform.status_active?

    client = resolve_client!(account, params[:client], from_insales: false)

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
      resolve_item!(incase, account, it, from_insales: false)
    end

    render json: { incase: { id: incase.id, status: incase.status, webform_id: webform.id, client_id: client.id } }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not found' }, status: :not_found
  end

  # Webhook endpoint для InSales orders/create
  def insales_order
    account = current_account || Account.find(params[:account_id])
    
    webform = account.webforms.find_by(kind: 'order', status: 'active')
    return render json: { error: 'order webform not active' }, status: :unprocessable_entity unless webform

    payload = request.request_parameters.deep_symbolize_keys
    order_data = payload[:order] || payload
    
    # Извлекаем данные клиента из order.client
    client_data = order_data[:client]
    return render json: { error: 'client data missing' }, status: :unprocessable_entity unless client_data
    
    client = resolve_client!(account, client_data, from_insales: true)

    # Создаем заявку с номером заказа из InSales, если он есть
    incase_attrs = { webform: webform, client: client, status: 'new' }
    incase_attrs[:number] = order_data[:number].to_s if order_data[:number].present?
    
    incase = account.incases.create!(incase_attrs)
    
    # Обрабатываем товары из order.order_lines
    Array(order_data[:order_lines]).each do |order_line|
      resolve_item!(incase, account, {
        variant_id: order_line[:variant_id],
        product_id: order_line[:product_id],
        quantity: order_line[:quantity],
        price: order_line[:sale_price] || order_line[:total_price]
      }, from_insales: true)
    end

    head :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def resolve_client!(account, client_params, from_insales: false)
    external_client_id = client_params&.dig(:id)
    email = client_params&.dig(:email)
    phone = client_params&.dig(:phone)
    insale = account.insales.first
    client = nil
    
    if external_client_id.present?
      if from_insales
        # Для webhook InSales: ищем через Varbind по внешнему ID
        if insale
          varbind = Varbind.find_by(
            varbindable: insale,
            record_type: "Client",
            value: external_client_id.to_s
          )
          client = varbind&.record
        end
      else
        # Для обычных форм: ищем по ID нашей БД
        client = account.clients.find_by(id: external_client_id)
      end
    end
    
    # Если не найден, ищем по email/phone
    unless client
      client = account.clients.where('email = ? OR phone = ?', email, phone).first
    end
    
    # Если клиент не найден, создаем нового
    unless client
      # Используем email или phone как fallback для name, если name пустой
      name = client_params[:name].presence || email.presence || phone.presence || "Client"
      client_attrs = { name: name, surname: client_params[:surname], email: email, phone: phone }
      client_attrs[:ya_client] = client_params[:ya_client_id] if client_params[:ya_client_id].present?
      client = account.clients.create!(client_attrs)
    end
    
    # Создаем varbind для связи с InSales, если его еще нет (для webhook InSales)
    if from_insales && insale && external_client_id.present?
      Varbind.find_or_create_by!(
        record: client,
        varbindable: insale,
        record_type: "Client",
        value: external_client_id.to_s
      )
    end
    
    # Обновляем ya_client если он изменился
    if client_params[:ya_client_id].present? && client.ya_client != client_params[:ya_client_id]
      client.update!(ya_client: client_params[:ya_client_id])
    end
    
    client
  end

  def resolve_item!(incase, account, item_params, from_insales: false)
    # item_params содержит: 
    # - для обычного API: type: "Variant", id: external_variant_id или internal_id, quantity, price
    # - для webhook InSales: variant_id: external_variant_id, product_id, quantity, price
    variant_id_param = item_params[:id] || item_params[:variant_id]
    external_variant_id = variant_id_param.to_s if variant_id_param.present?
    quantity = item_params[:quantity] || 1
    price = item_params[:price] || 0

    insale = account.insales.first
    variant = nil
    
    if from_insales
      # Для webhook InSales: всегда ищем через Varbind по external_id
      if insale && external_variant_id.present?
        varbind = Varbind.find_by(
          varbindable: insale,
          record_type: "Variant",
          value: external_variant_id
        )
        variant = varbind&.record
      end
    else
      # Для обычных форм: сначала проверяем, не является ли это ID нашей БД
      if variant_id_param.present?
        variant = account.variants.joins(:product).where(products: { account_id: account.id }).find_by(id: variant_id_param)
      end
      
      # Если не найден по ID нашей БД, ищем через Varbind по external_id
      if variant.nil? && insale && external_variant_id.present?
        varbind = Varbind.find_by(
          varbindable: insale,
          record_type: "Variant",
          value: external_variant_id
        )
        variant = varbind&.record
      end
    end

    # Если variant не найден, создаем его
    unless variant
      # Пытаемся найти product по external_product_id, если он есть
      product = nil
      if item_params[:product_id].present?
        if from_insales
          # Для InSales webhook: ищем через Varbind
          product_varbind = Varbind.find_by(
            varbindable: insale,
            record_type: "Product",
            value: item_params[:product_id].to_s
          )
          product = product_varbind&.record
        else
          # Для обычных форм: сначала проверяем ID нашей БД
          product = account.products.find_by(id: item_params[:product_id])
          # Если не найден, ищем через Varbind
          if product.nil? && insale
            product_varbind = Varbind.find_by(
              varbindable: insale,
              record_type: "Product",
              value: item_params[:product_id].to_s
            )
            product = product_varbind&.record
          end
        end
      end

      # Если product не найден, создаем новый
      product ||= account.products.create!(title: "API Product #{item_params[:product_id] || 'Unknown'}")

      # Создаем varbind для product только для InSales webhook
      if from_insales && insale && item_params[:product_id].present?
        Varbind.find_or_create_by!(
          record: product,
          varbindable: insale,
          record_type: "Product",
          value: item_params[:product_id].to_s
        )
      end

      # Создаем variant
      variant = product.variants.create!
      
      # Создаем varbind для variant только для InSales webhook
      if from_insales && insale && external_variant_id.present?
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