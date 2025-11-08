module Billing
  module Gateways
    class Base
      class << self
        def gateway_for(provider_type)
          case provider_type.to_s
          when "paymaster"
            Paymaster.new
          when "invoice"
            Invoice.new
          when "cash"
            Cash.new
          else
            raise ArgumentError, "Unknown provider type: #{provider_type}"
          end
        end
      end

      def create_subscription(account:, plan:, **options)
        raise NotImplementedError, "Subclasses must implement create_subscription"
      end

      def create_payment(subscription:, amount:)
        raise NotImplementedError, "Subclasses must implement create_payment"
      end

      def cancel_subscription(subscription:)
        raise NotImplementedError, "Subclasses must implement cancel_subscription"
      end
    end
  end
end

