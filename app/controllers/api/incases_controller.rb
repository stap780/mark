class Api::IncasesController < ApplicationController
  skip_before_action :require_authentication, raise: false
  skip_before_action :verify_authenticity_token

  def create
    account = current_account || Account.find(params[:account_id])
    webform = account.webforms.find(params.require(:webform_id))
    render json: { error: 'webform inactive' }, status: :unprocessable_entity and return unless webform.status_active?

    # Honeypot-поле для защиты от ботов.
    # На клиенте поле называется "website" и скрыто от пользователей.
    # Если оно заполнено, считаем запрос ботом и тихо отклоняем его с логированием.
    if client_params[:website].present?
      Rails.logger.warn(
        "Bot detected via honeypot field for account ##{account.id}, " \
        "webform ##{webform.id}, ip=#{request.remote_ip}"
      )
      return render json: { error: 'invalid request' }, status: :unprocessable_entity
    end

    client = resolve_client!(account, client_params, from_insales: false)

    # Проверяем, что items переданы (для всех форм кроме custom)
    # Для кастомных форм items не обязательны
    if params[:items].blank? && webform.kind != 'custom'
      return render json: { error: 'items are required' }, status: :unprocessable_entity
    end

    # Подготавливаем атрибуты для создания заявки
    incase_attrs = { webform: webform, client: client, status: 'new' }
    incase_attrs[:number] = incase_params[:number] if incase_params[:number].present?
    incase_attrs[:custom_fields] = incase_params[:custom_fields] if incase_params[:custom_fields].present?

    # Проверяем существующую заявку по number для всех типов форм
    if incase_attrs[:number].present?
      incase = account.incases.find_by(number: incase_attrs[:number], webform: webform)
      
      if incase
        # Обновляем существующую заявку: удаляем старые items и создаем новые
        incase.items.destroy_all
        update_attrs = {}
        update_attrs[:client] = client if client != incase.client
        update_attrs[:custom_fields] = incase_attrs[:custom_fields] if incase_attrs[:custom_fields].present?
        incase.update!(update_attrs) if update_attrs.any?
      else
        # Создаем новую заявку с number
        incase = account.incases.create!(incase_attrs)
      end
    else
      # Если number не передан, создаем новую заявку без number
      incase = account.incases.create!(incase_attrs)
    end

    items = Array(params[:items]).map do |it|
      resolve_item!(incase, account, it, from_insales: false)
    end

    # Запускаем автоматику после того, как заявка и все позиции созданы
    Automation::Engine.call(
      account: account,
      event: "incase.created",
      object: incase
    )

    render json: { incase: { id: incase.id, status: incase.status, webform_id: webform.id, client_id: client.id } }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Incase/Item validation failed: #{e.record.errors.full_messages}"
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'not found' }, status: :not_found
  end

  # Webhook endpoint для InSales orders/create
  def insales_order
    account = current_account || Account.find(params[:account_id])
    payload = request.request_parameters.deep_symbolize_keys
    order_data = payload[:order] || payload

    InsalesOrderIncaseCreator.call(account: account, order_data: order_data)
    head :ok
  rescue InsalesOrderIncaseCreator::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Incase/Item validation failed: #{e.record.errors.full_messages}"
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def client_params
    params.require(:client).permit(:name, :surname, :email, :phone, :website, :ya_client_id)
  end

  def incase_params
    params.permit(:number, custom_fields: {})
  end

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
    
    # Если не найден, ищем по email/phone (только если значения не пустые)
    unless client
      conditions = []
      conditions_params = []
      
      if email.present?
        conditions << 'email = ?'
        conditions_params << email
      end
      
      if phone.present?
        conditions << 'phone = ?'
        conditions_params << phone
      end
      
      if conditions.any?
        client = account.clients.where(conditions.join(' OR '), *conditions_params).first
      end
    end
    
    # Если клиент не найден, создаем нового
    unless client
      # Используем email или phone как fallback для name, если name пустой
      name = client_params[:name].presence || email.presence || phone.presence || "Client"
      client_attrs = { name: name, surname: client_params[:surname], email: email, phone: phone }
      client_attrs[:ya_client] = client_params[:ya_client_id] if client_params[:ya_client_id].present?
      client = account.clients.create!(client_attrs)
    else
      # Обновляем данные существующего клиента, если они отсутствуют или изменились
      update_attrs = {}
      
      # Обновляем имя, если оно пустое или не задано
      if client.name.blank? && client_params[:name].present?
        update_attrs[:name] = client_params[:name]
      end
      
      # Обновляем фамилию, если она пустая или не задана
      if client.surname.blank? && client_params[:surname].present?
        update_attrs[:surname] = client_params[:surname]
      end
      
      # Обновляем email, если он пустой или не задан
      if client.email.blank? && email.present?
        update_attrs[:email] = email
      end
      
      # Обновляем телефон, если он пустой или не задан
      if client.phone.blank? && phone.present?
        update_attrs[:phone] = phone
      end
      
      # Обновляем клиента, если есть изменения
      if update_attrs.any?
        client.update!(update_attrs)
      end
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

  # Возвращает хеш атрибутов для Item (для nested attributes). Не создаёт запись.
  def resolve_item_attributes!(account, item_params, from_insales: false)
    variant_id_param = item_params[:id] || item_params[:variant_id]
    external_variant_id = variant_id_param.to_s if variant_id_param.present?
    quantity = item_params[:quantity] || 1
    price = item_params[:price] || 0

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

    unless variant
      product = nil
      if item_params[:product_id].present? && insale
        product_varbind = Varbind.find_by(
          varbindable: insale,
          record_type: "Product",
          value: item_params[:product_id].to_s
        )
        product = product_varbind&.record
      end

      product ||= account.products.create!(title: "API Product #{item_params[:product_id] || 'Unknown'}")

      if from_insales && insale && item_params[:product_id].present?
        Varbind.find_or_create_by!(
          record: product,
          varbindable: insale,
          record_type: "Product",
          value: item_params[:product_id].to_s
        )
      end

      variant = product.variants.create!

      if from_insales && insale && external_variant_id.present?
        Varbind.find_or_create_by!(
          record: variant,
          varbindable: insale,
          record_type: "Variant",
          value: external_variant_id
        )
      end
    end

    if variant && insale
      product = variant.product

      if item_params[:product_id].present?
        Varbind.find_or_create_by!(
          record: product,
          varbindable: insale,
          record_type: "Product",
          value: item_params[:product_id].to_s
        )
      end

      if external_variant_id.present?
        Varbind.find_or_create_by!(
          record: variant,
          varbindable: insale,
          record_type: "Variant",
          value: external_variant_id
        )
      end
    end

    {
      product_id: variant.product_id,
      variant_id: variant.id,
      quantity: quantity,
      price: price
    }
  end

  def resolve_item!(incase, account, item_params, from_insales: false)
    attrs = resolve_item_attributes!(account, item_params, from_insales: from_insales)

    # Для заявок типа "notify" устанавливаем quantity = 0 у варианта
    if incase.webform.kind == 'notify'
      Variant.find(attrs[:variant_id]).update_column(:quantity, 0)
    end

    incase.items.create!(attrs)
  end

  
end