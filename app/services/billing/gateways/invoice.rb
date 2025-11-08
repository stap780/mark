module Billing
  module Gateways
    class Invoice < Base
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
          processor: :invoice,
          processor_data: {}
        )

        { subscription: subscription, payment: payment }
      end

      def create_payment(subscription:, amount:)
        payment = subscription.payments.create!(
          amount: amount,
          status: :pending,
          processor: :invoice,
          processor_data: {}
        )

        { payment: payment }
      end

      def cancel_subscription(subscription:)
        subscription.update!(status: :canceled)
        subscription
      end

      def generate_pdf(payment)
        subscription = payment.subscription
        account = subscription.account
        plan = subscription.plan

        receipt = Receipts::Receipt.new(
          id: payment.id,
          product: plan.name,
          company: {
            name: "Mark",
            address: "Адрес компании",
            email: "support@example.com",
            logo: nil
          },
          line_items: [
            ["Название", "Количество", "Цена", "Сумма"],
            [plan.name, "1", "#{plan.price} ₽", "#{payment.amount} ₽"]
          ],
          font: {
            bold: nil,
            normal: nil
          }
        )

        receipt.to_pdf
      end

      private

      # Номер счета используем как id платежа
    end
  end
end

