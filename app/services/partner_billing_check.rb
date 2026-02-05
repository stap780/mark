class PartnerBillingCheck
  Result = Struct.new(
    :success?,
    :status,
    :paid_till,
    :trial_expired_at,
    :blocked,
    :error,
    keyword_init: true
  )

  SUPPORTED_APPS = %w[inswatch insnotify].freeze

  def self.call(account, app_key: nil)
    new(account, app_key: app_key).call
  end

  def initialize(account, app_key: nil)
    @account = account
    @app_key = app_key || detect_app_key
  end

  def call
    unless SUPPORTED_APPS.include?(app_key)
      return Result.new(
        success?: false,
        error: "Unsupported or missing partner app for account ##{account.id}"
      )
    end

    insale = load_insale_record
    unless insale
      return Result.new(
        success?: false,
        error: "No InSales configuration (Insale) for account ##{account.id}"
      )
    end

    data = fetch_recurring_charge(insale)
    return data if data.is_a?(Result) # early return on failure

    status_result = InsalesChargeStatus.call(data)

    subscription = sync_subscription(data, status_result)

    Result.new(
      success?: true,
      status: subscription.status,
      paid_till: data["paid_till"],
      trial_expired_at: data["trial_expired_at"],
      blocked: data["blocked"]
    )
  rescue StandardError => e
    Rails.logger.error "PartnerBillingCheck error for account ##{account.id}: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    Result.new(success?: false, error: e.message)
  end

  private

  attr_reader :account, :app_key

  def detect_app_key
    apps = account.settings.is_a?(Hash) ? Array(account.settings["apps"]) : []
    apps.find { |app| SUPPORTED_APPS.include?(app) }
  end

  def load_insale_record
    # Inswatch/Insnotify create a single Insale record per partner account
    Account.switch_to(account.id)
    account.insales.first
  end

  def fetch_recurring_charge(insale)
    insale.api_init

    charge = InsalesApi::RecurringApplicationCharge.find
    unless charge && charge.respond_to?(:attributes)
      return Result.new(success?: false, error: "No recurring charge found in InSales")
    end

    charge.attributes.dup.transform_keys(&:to_s)
  rescue ActiveResource::ResourceNotFound
    Result.new(success?: false, error: "Recurring charge not found in InSales")
  rescue ActiveResource::UnauthorizedAccess
    Result.new(success?: false, error: "Unauthorized in InSales API (check credentials)")
  rescue ActiveResource::ForbiddenAccess
    Result.new(success?: false, error: "Forbidden in InSales API (check app permissions)")
  rescue StandardError => e
    Rails.logger.error "Error fetching recurring charge for account ##{account.id}: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    Result.new(success?: false, error: "Failed to fetch recurring charge: #{e.message}")
  end

  def sync_subscription(data, status_result)
    plan = find_or_create_plan

    subscription = account.subscriptions.where(plan: plan).first_or_initialize

    access_until = status_result.access_until
    now = Time.current

    subscription.current_period_start ||= now
    subscription.current_period_end = access_until&.end_of_day if access_until

    subscription.status =
      case status_result.status
      when "active"
        if access_until && access_until >= Date.current
          "active"
        else
          "canceled"
        end
      when "pending"
        if access_until && access_until >= Date.current
          "trialing"
        else
          "canceled"
        end
      when "declined", "cancelled"
        "canceled"
      else
        # Если статус нам неизвестен, оставляем как есть или помечаем incomplete
        subscription.status.presence || "incomplete"
      end

    subscription.save!
    subscription
  end

  def find_or_create_plan
    config = plan_config_for(app_key)

    Plan.find_or_create_by!(name: config.fetch(:name)) do |plan|
      plan.price = config.fetch(:price)
      plan.interval = "monthly"
      plan.active = true
      plan.trial_days = 10
    end
  end

  def plan_config_for(app_key)
    case app_key
    when "inswatch"
      { name: "inswatch 799", price: 799 }
    when "insnotify"
      { name: "insnotify 799", price: 799 }
    else
      raise ArgumentError, "Unsupported app_key: #{app_key.inspect}"
    end
  end
end

