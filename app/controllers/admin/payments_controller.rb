class Admin::PaymentsController < ApplicationController
  include ActionView::RecordIdentifier

  skip_before_action :ensure_user_in_current_account
  before_action :ensure_super_admin_account
  before_action :set_payment, only: [:show, :update]

  def index
    @search = Payment
      .includes(subscription: [:account, :plan])
      .ransack(params[:q])
    @search.sorts = "created_at desc" if @search.sorts.empty?
    @payments = @search.result(distinct: true).paginate(page: params[:page], per_page: 50)
  end

  def show
  end

  def update
    # Allow super-admin to mark payment status (subscription will be updated automatically via callback)
    permitted = params.require(:payment).permit(:status)

    @payment.update!(permitted)

    respond_to do |format|
      flash.now[:success] = t('.success', default: 'Payment updated successfully')
      format.turbo_stream do
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.replace(dom_id(@payment), partial: "admin/payments/payment", locals: { payment: @payment })
        ]
      end
      format.html { redirect_to admin_payment_path(@payment), notice: t('.success') }
      format.json { render :show, status: :ok, location: admin_payment_path(@payment) }
    end
  rescue => e
    respond_to do |format|
      flash.now[:error] = e.message
      format.html { render :show, status: :unprocessable_entity }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def set_payment
    @payment = Payment.find(params[:id])
  end

  def ensure_super_admin_account
    user_accounts = Current.session&.user&.accounts || []
    admin_account = user_accounts.find { |acc| acc.admin? }
    unless admin_account
      flash[:error] = t('accounts.access_denied', default: 'Access denied. Admin account privileges required.')
      if user_accounts.any?
        redirect_to account_dashboard_path(user_accounts.first)
      else
        redirect_to root_path
      end
    end
  end
end


