class Api::DiscountsController < ApplicationController
  # Отключаем CSRF защиту для API endpoints
  skip_before_action :verify_authenticity_token
  
  # POST /api/accounts/:account_id/discounts/calc
  # Принимает полную структуру данных заказа из Insales
  # Возвращает примененную скидку или ошибку
  def calc
    Rails.logger.info "Discount calc params: #{params.inspect}"
    
    result = Discounts::Calc.call(
      account: current_account,
      data: params.permit!.to_h.except(:controller, :action, :account_id)
    )
    
    render json: result
  end
end