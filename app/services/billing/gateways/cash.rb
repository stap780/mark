module Billing
  module Gateways
    class Cash < Base
      def create_subscription(account:, plan:, **options)
        subscription = account.subscriptions.create!(
          plan_id: plan.id,
          status: :incomplete,
          current_period_start: Time.current,
          current_period_end: Time.current + 1.month
        )

        payment = subscription.payments.create!(
          amount: plan.price,
          status: :pending,
          processor: :cash,
          processor_data: {}
        )

        { subscription: subscription, payment: payment }
      end

      def create_payment(subscription:, amount:)
        payment = subscription.payments.create!(
          amount: amount,
          status: :pending,
          processor: :cash,
          processor_data: {}
        )

        { payment: payment }
      end

      def cancel_subscription(subscription:)
        subscription.update!(status: :canceled)
        subscription
      end
    end
  end
end

