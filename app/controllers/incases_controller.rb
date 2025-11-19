class IncasesController < ApplicationController
  include ActionView::RecordIdentifier
  
  before_action :set_incase, only: [:show, :update_status]

  def index
    @incases = current_account.incases.includes(:client, :webform).order(created_at: :desc).paginate(page: params[:page], per_page: 50)
  end

  def show; end

  def update_status
    respond_to do |format|
      if @incase.update(status: params.require(:status))
        format.turbo_stream do
          flash.now[:success] = t(:success)
          render turbo_stream: [
            turbo_stream.update("incase_status_#{@incase.id}", partial: "incases/status", locals: { incase: @incase }),
            render_turbo_flash
          ]
          format.html { redirect_to account_incase_path(current_account, @incase), notice: 'Status updated' }
        end
      else
        format.turbo_stream do
          flash.now[:alert] = @incase.errors.full_messages.join(', ')
          render turbo_stream: [render_turbo_flash]
        end
        format.html { redirect_to account_incase_path(current_account, @incase), alert: @incase.errors.full_messages.join(', ') }
      end
    end
  end

  private

  def set_incase
    @incase = current_account.incases.find(params[:id])
  end
end


