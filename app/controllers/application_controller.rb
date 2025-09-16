class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_account
  before_action :ensure_user_in_current_account

  private

  def set_current_account
    Current.account = Account.find_by(id: params[:account_id])
  end

  def ensure_user_in_current_account
    return unless Current.session && Current.account
    # Ensure the authenticated user belongs to the current account
    if Current.session.user.account_id != Current.account.id
      terminate_session
      redirect_to new_session_path, alert: "Please sign in for this account."
    end
  end
end
