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
      incase.incase_items.create!(item_type: 'Variant', item_id: it[:variant_id], quantity: it[:quantity], price: it[:price])
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
end


