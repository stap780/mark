class PaymentsController < ApplicationController
  include ActionView::RecordIdentifier
  include OffcanvasResponder
  
  before_action :ensure_account_admin, only: [:index, :show]
  before_action :set_subscription, only: [:new, :create]
  before_action :set_payment, only: [:show]

  def index
    @search = current_account
      .payments
      .includes(subscription: :plan)
      .ransack(params[:q])
    @search.sorts = "created_at desc" if @search.sorts.empty?
    @payments = @search.result(distinct: true).paginate(page: params[:page], per_page: 50)
  end

  def show; end

  def new
    @payment = @subscription.payments.build
  end

  def create
    @payment = @subscription.payments.build(payment_params)

    respond_to do |format|
      if @payment.save
        if @payment.processor == 'paymaster'
          # Для Paymaster получаем redirect_url после создания платежа
          gateway = Billing::Gateways::Base.gateway_for('paymaster')
          redirect_url = gateway.build_payment_url(payment: @payment, subscription: @subscription)
          
          format.html { redirect_to redirect_url, allow_other_host: true }
          format.json { render json: { redirect_url: redirect_url }, status: :created }
        else
          flash.now[:success] = t('.success')
          format.turbo_stream do
            render turbo_stream: turbo_close_offcanvas_flash + [
              turbo_stream.replace(
                dom_id(current_account, dom_id(@subscription)),
                partial: "subscriptions/subscription",
                locals: { subscription: @subscription }
              )
            ]
          end
          format.html { redirect_to account_subscription_path(current_account, @subscription), notice: t('.success') }
          format.json { render :show, status: :created, location: account_payment_path(current_account, @payment) }
        end
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @payment.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_subscription
    @subscription = current_account.subscriptions.find(params[:subscription_id])
  end

  def set_payment
    @payment = current_account
      .payments
      .includes(subscription: :plan)
      .find(params[:id])
  end

  def payment_params
    params.require(:payment).permit(:processor, :amount)
  end

end