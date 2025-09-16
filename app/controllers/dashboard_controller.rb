class DashboardController < ApplicationController
  def index
    redirect_to new_session_path and return unless Current.account
  end
end
