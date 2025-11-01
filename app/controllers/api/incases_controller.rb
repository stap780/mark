class Api::IncasesController < ApplicationController
  skip_before_action :require_authentication, raise: false
  skip_before_action :verify_authenticity_token

  def create
    account = Account.find(params[:account_id])
    webform = account.webforms.find(params.require(:webform_id))
    render json: { error: 'webform inactive' }, status: :unprocessable_entity and return unless webform.status_active?

    client = resolve_client!(account, params[:client])

    incase = account.incases.create!(webform: webform, client: client, status: 'new')
    items = Array(params[:items]).map do |it|
      incase.incase_items.create!(item_type: it[:type], item_id: it[:id], quantity: it[:quantity], price: it[:price])
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
    client ||= account.clients.create!(name: client_params[:name], surname: client_params[:surname], email: email, phone: phone)
    client
  end
end


