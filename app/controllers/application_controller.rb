class ApplicationController < ActionController::Base
  include Authentication
  include OffcanvasResponder
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :load_session
  before_action :set_current_account
  before_action :ensure_user_in_current_account
  helper_method :current_account

  private

  # Hotwire helper to update the flash container via turbo_stream
  def render_turbo_flash
    turbo_stream.replace("flash", partial: "shared/flash")
  end

  def load_session
    # Ensure Current.session is available even on unauthenticated pages
    if Current.session.nil? && respond_to?(:find_session_by_cookie, true)
      Current.session = find_session_by_cookie
    end
  end

  def set_current_account
    # Current.account = Account.find_by(id: params[:account_id])
    Current.account =
    if params[:account_id].present?
      Account.find_by(id: params[:account_id])
    elsif Current.session&.user
      # If user is admin, you might want a preferred/default account:
      Current.session.user.account || Account.where(admin: true).first
    end
  end

  def ensure_user_in_current_account
    return unless Current.session && Current.account
    # Allow global admin account to access any account scope
    return if Current.session.user && Current.session.user.account&.admin?
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
