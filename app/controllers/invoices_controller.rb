class InvoicesController < ApplicationController
  before_action :ensure_account_admin
  before_action :set_payment

  def show
    respond_to do |format|
      format.html
      format.pdf do
        if @payment.invoice?
          gateway = Billing::Gateways::Invoice.new
          pdf = gateway.generate_pdf(@payment)
    send_data pdf, filename: "invoice_#{@payment.id}.pdf", type: "application/pdf", disposition: "inline"
        else
          redirect_to account_payment_path(current_account, @payment), alert: t('.not_invoice', default: 'This payment is not an invoice')
        end
      end
    end
  end

  private

  def set_payment
    @payment = current_account.payments.find(params[:id])
  end

  def ensure_account_admin
    return unless Current.session && Current.account
    
    account_user = Current.session.user.account_users.find_by(account: Current.account)
    unless account_user&.admin?
      flash[:error] = t('invoices.access_denied', default: 'Access denied. Admin privileges required.')
      redirect_to account_dashboard_path(Current.account)
    end
  end
end

