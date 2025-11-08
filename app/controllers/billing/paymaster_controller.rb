module Billing
  class PaymasterController < ApplicationController
    skip_before_action :ensure_user_in_current_account
    skip_before_action :verify_authenticity_token, only: [:success, :fail, :result]

    def success
      payment = find_payment
      return redirect_to root_path, alert: t('.payment_not_found', default: 'Payment not found') unless payment

      update_payment_status(payment)

      redirect_to account_subscription_path(payment.subscription.account, payment.subscription), notice: t('.success', default: 'Payment successful')
    end

    def fail
      redirect_to root_path, alert: t('.payment_failed', default: 'Payment failed')
    end

    def result
      payment = find_payment
      return head :ok unless payment

      # Проверка идемпотентности
      # Idempotency check can be done against processor_data if needed later

      # Subscription will be activated automatically via Payment callback
      update_payment_status(payment)

      head :ok
    end

    private

    def find_payment
      return nil unless params[:LMI_PAYMENT_NO].present?
      
      payment = Payment.find_by(id: params[:LMI_PAYMENT_NO])
      return nil unless payment&.paymaster?
      
      # Проверка, что пользователь соответствует
      account_id = params[:LMI_CURRENT_USER] || payment.subscription.account_id
      return nil unless payment.subscription.account_id == account_id.to_i

      payment
    end

    def update_payment_status(payment)
      payment.update!(
        processor_id: params[:LMI_SYS_PAYMENT_ID],
        processor_data: params.to_unsafe_h,
        status: :succeeded,
        paid_at: Time.current
      )
    end
  end
end

