class ApplicationController < ActionController::Base
  include Authentication
  include OffcanvasResponder
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_account
  before_action :ensure_user_in_current_account
  helper_method :current_account

  private

  # Hotwire helper to update the flash container via turbo_stream
  def render_turbo_flash
    turbo_stream.replace("flash", partial: "shared/flash")
  end

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

  def current_account
    Current.account
  end
end
