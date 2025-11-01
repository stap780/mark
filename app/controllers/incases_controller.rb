class IncasesController < ApplicationController
  before_action :set_incase, only: [:show, :update_status]

  def index
    @incases = current_account.incases.includes(:client, :webform).order(created_at: :desc)
  end

  def show; end

  def update_status
    if @incase.update(status: params.require(:status))
      redirect_to @incase, notice: 'Status updated'
    else
      redirect_to @incase, alert: @incase.errors.full_messages.join(', ')
    end
  end

  private

  def set_incase
    @incase = current_account.incases.find(params[:id])
  end
end


