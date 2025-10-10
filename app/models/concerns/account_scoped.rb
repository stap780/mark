module AccountScoped
  extend ActiveSupport::Concern

  included do
    # Default scope to filter by current account
    default_scope { where(account: Account.current) if Account.current }
  end
end
