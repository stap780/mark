class Admin::DashboardController < ApplicationController
  skip_before_action :ensure_user_in_current_account
  before_action :ensure_super_admin_account

  def index
    @accounts_count = Account.count
    @users_count = User.count
    @account_users_count = AccountUser.count
  end

  private

  def ensure_super_admin_account
    user_accounts = Current.session&.user&.accounts || []
    admin_account = user_accounts.find { |acc| acc.admin? }
    unless admin_account
      flash[:error] = t('accounts.access_denied', default: 'Access denied. Admin account privileges required.')
      if user_accounts.any?
        redirect_to account_dashboard_path(user_accounts.first)
      else
        redirect_to root_path
      end
    end
  end
end


