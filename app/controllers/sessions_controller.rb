class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
    if Current.session&.user
      first_account = Current.session.user.accounts.first
      return redirect_to account_dashboard_path(first_account.id) if first_account
    end
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url, notice: "Signed in"
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "Signed out"
  end

  private
    def after_authentication_url
      first_account = Current.session.user.accounts.first
      return new_session_path unless first_account
      account_dashboard_path(first_account)
    end
end
