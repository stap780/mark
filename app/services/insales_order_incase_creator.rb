# Создаёт или обновляет заявку (Incase) типа order из данных в формате InSales (order_lines, client, number).
# Используется webhook'ами insales_order (orders/create и orders/update) и rake-задачей incase:create_order.
# При наличии number ищет существующую заявку и обновляет её (upsert).
class InsalesOrderIncaseCreator
  class Error < StandardError; end

  def self.call(account:, order_data:)
    new(account: account, order_data: order_data).call
  end

  def initialize(account:, order_data:)
    @account = account
    @order_data = order_data.deep_symbolize_keys
  end

  def call
    webform = @account.webforms.find_by(kind: 'order', status: 'active')
    raise Error, 'order webform not active' unless webform

    client_data = @order_data[:client]
    raise Error, 'client data missing' unless client_data

    client = resolve_client!(client_data)
    order_lines = Array(@order_data[:order_lines])
    raise Error, 'order_lines are required' if order_lines.blank?

    items_attributes = order_lines.each_with_index.to_h do |order_line, index|
      attrs = resolve_item_attributes!(
        variant_id: order_line[:variant_id],
        product_id: order_line[:product_id],
        quantity: order_line[:quantity],
        price: order_line[:sale_price] || order_line[:total_price]
      )
      [index.to_s, attrs]
    end

    number = @order_data[:number].to_s if @order_data[:number].present?
    order_id = @order_data[:id].to_s if @order_data[:id].present?
    incase = find_existing_incase(webform, number, order_id)

    incase_status_id = resolve_incase_status_id

    if incase
      incase.items.destroy_all
      incase.update!(
        client_id: client.id,
        number: number,
        incase_status_id: incase_status_id,
        items_attributes: items_attributes
      )
      save_order_id_varbind!(incase, order_id)
    else
      incase_attrs = {
        webform_id: webform.id,
        client_id: client.id,
        incase_status_id: incase_status_id,
        number: number,
        items_attributes: items_attributes
      }
      incase = @account.incases.create!(incase_attrs)
      save_order_id_varbind!(incase, order_id)
    end

    incase
  end

  private

  def find_existing_incase(webform, number, order_id)
    insale = @account.insales.first

    if insale && order_id.present?
      varbind = Varbind.find_by(
        varbindable: insale,
        record_type: "Incase",
        value: order_id
      )
      return varbind&.record if varbind
    end

    return nil if number.blank?
    @account.incases.find_by(webform: webform, number: number)
  end

  def resolve_incase_status_id
    insale = @account.insales.first
    return default_incase_status_id unless insale

    permalink = @order_data.dig(:custom_status, :permalink).to_s.presence
    financial_status = @order_data[:financial_status].to_s.presence

    return default_incase_status_id if permalink.blank? || financial_status.blank?

    mapping = insale.insale_status_mappings.find_by(
      insales_custom_status_permalink: permalink,
      insales_financial_status: financial_status
    )

    mapping&.incase_status_id || default_incase_status_id
  end

  def default_incase_status_id
    @account.incase_statuses.find_by(key: "new")&.id || @account.incase_statuses.first&.id
  end

  def save_order_id_varbind!(incase, order_id)
    return if order_id.blank?

    insale = @account.insales.first
    return unless insale

    Varbind.find_or_create_by!(
      record: incase,
      varbindable: insale,
      record_type: "Incase",
      value: order_id
    )
  end

  def resolve_client!(client_params)
    external_client_id = client_params&.dig(:id)
    email = client_params&.dig(:email)
    phone = client_params&.dig(:phone)
    insale = @account.insales.first
    client = nil

    if external_client_id.present? && insale
      varbind = Varbind.find_by(
        varbindable: insale,
        record_type: "Client",
        value: external_client_id.to_s
      )
      client = varbind&.record
    end

    unless client
      conditions = []
      conditions_params = []
      conditions << 'email = ?' if email.present?
      conditions_params << email if email.present?
      conditions << 'phone = ?' if phone.present?
      conditions_params << phone if phone.present?
      client = @account.clients.where(conditions.join(' OR '), *conditions_params).first if conditions.any?
    end

    unless client
      name = client_params[:name].presence || email.presence || phone.presence || "Client"
      client_attrs = { name: name, surname: client_params[:surname], email: email, phone: phone }
      client_attrs[:ya_client] = client_params[:ya_client_id] if client_params[:ya_client_id].present?
      client = @account.clients.create!(client_attrs)
    else
      update_attrs = {}
      update_attrs[:name] = client_params[:name] if client.name.blank? && client_params[:name].present?
      update_attrs[:surname] = client_params[:surname] if client.surname.blank? && client_params[:surname].present?
      update_attrs[:email] = email if client.email.blank? && email.present?
      update_attrs[:phone] = phone if client.phone.blank? && phone.present?
      client.update!(update_attrs) if update_attrs.any?
    end

    if insale && external_client_id.present?
      Varbind.find_or_create_by!(
        record: client,
        varbindable: insale,
        record_type: "Client",
        value: external_client_id.to_s
      )
    end

    client.update!(ya_client: client_params[:ya_client_id]) if client_params[:ya_client_id].present? && client.ya_client != client_params[:ya_client_id]

    client
  end

  def resolve_item_attributes!(variant_id: nil, product_id: nil, quantity: 1, price: 0)
    external_variant_id = variant_id.to_s.presence
    insale = @account.insales.first
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
      if product_id.present? && insale
        product_varbind = Varbind.find_by(
          varbindable: insale,
          record_type: "Product",
          value: product_id.to_s
        )
        product = product_varbind&.record
      end
      product ||= @account.products.create!(title: "API Product #{product_id || 'Unknown'}")
      if insale && product_id.present?
        Varbind.find_or_create_by!(
          record: product,
          varbindable: insale,
          record_type: "Product",
          value: product_id.to_s
        )
      end
      variant = product.variants.create!
      if insale && external_variant_id.present?
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
      Varbind.find_or_create_by!(
        record: product,
        varbindable: insale,
        record_type: "Product",
        value: product_id.to_s
      ) if product_id.present?
      Varbind.find_or_create_by!(
        record: variant,
        varbindable: insale,
        record_type: "Variant",
        value: external_variant_id
      ) if external_variant_id.present?
    end

    {
      product_id: variant.product_id,
      variant_id: variant.id,
      quantity: quantity,
      price: price
    }
  end
  
end
