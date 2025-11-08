module Billing
  module Gateways
    class Paymaster < Base
      def create_subscription(account:, plan:, **options)
        period_months = plan.interval_months
        subscription = account.subscriptions.create!(
          plan_id: plan.id,
          status: :incomplete,
          current_period_start: Time.current,
          current_period_end: Time.current + period_months.months
        )

        payment = subscription.payments.create!(
          amount: plan.price,
          status: :pending,
          processor: :paymaster,
          processor_data: {}
        )

        redirect_url = build_paymaster_url(payment: payment, subscription: subscription)
        
        { subscription: subscription, payment: payment, redirect_url: redirect_url }
      end

      def create_payment(subscription:, amount:)
        payment = subscription.payments.create!(
          amount: amount,
          status: :pending,
          processor: :paymaster,
          processor_data: {}
        )

        redirect_url = build_paymaster_url(payment: payment, subscription: subscription)
        
        { payment: payment, redirect_url: redirect_url }
      end

      def cancel_subscription(subscription:)
        subscription.update!(status: :canceled)
        subscription
      end

      def build_payment_url(payment:, subscription:)
        build_paymaster_url(payment: payment, subscription: subscription)
      end

      private

      def build_paymaster_url(payment:, subscription:)
        # TODO: Реализовать формирование URL для Paymaster
        # Использовать конфигурацию из Billing.config
        base_url = Rails.application.credentials.dig(:paymaster, :base_url) || "https://paymaster.ru"
        
        params = {
          LMI_MERCHANT_ID: Rails.application.credentials.dig(:paymaster, :merchant_id),
          LMI_PAYMENT_AMOUNT: payment.amount,
          LMI_PAYMENT_NO: payment.id,
          LMI_PAYMENT_DESC: "Подписка #{subscription.plan&.name || 'Plan'}",
          LMI_CURRENT_USER: subscription.account.id,
          LMI_SUCCESS_URL: Rails.application.routes.url_helpers.billing_paymaster_success_url,
          LMI_FAIL_URL: Rails.application.routes.url_helpers.billing_paymaster_fail_url,
          LMI_RESULT_URL: Rails.application.routes.url_helpers.billing_paymaster_result_url
        }

        "#{base_url}/payment?#{params.to_query}"
      end
    end
  end
end

