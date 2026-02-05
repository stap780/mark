class InsalesChargeStatus
  Result = Struct.new(:status, :access_until, keyword_init: true)

  def self.call(data)
    new(data || {}).call
  end

  def initialize(raw_data)
    @blocked          = truthy?(raw_data["blocked"])
    @paid_till        = parse_date(raw_data["paid_till"])
    @trial_expired_at = parse_date(raw_data["trial_expired_at"])
  end

  def call
    return Result.new(status: "cancelled", access_until: access_date) if blocked?

    if paid_till.present?
      if today <= paid_till
        return Result.new(status: "active", access_until: paid_till)
      else
        # Платный период истёк
        return Result.new(status: "declined", access_until: paid_till)
      end
    end

    if trial_expired_at.present? && today <= trial_expired_at
      return Result.new(status: "pending", access_until: trial_expired_at)
    end

    Result.new(status: "pending", access_until: access_date)
  end

  private

  attr_reader :paid_till, :trial_expired_at

  def today
    @today ||= Date.current
  end

  def blocked?
    @blocked == true
  end

  def access_date
    paid_till || trial_expired_at
  end

  def parse_date(value)
    return nil if value.blank?

    case value
    when Date
      value
    when Time, ActiveSupport::TimeWithZone
      value.to_date
    else
      Date.parse(value.to_s)
    end
  rescue ArgumentError
    nil
  end

  def truthy?(value)
    value == true || value.to_s == "true"
  end
end

