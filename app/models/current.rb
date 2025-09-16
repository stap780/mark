class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :account

  delegate :user, to: :session, allow_nil: true

  def account=(account)
    super
  # Clear session context if account is being cleared to avoid cross-account leakage
  self.session = nil unless account
  end
end
