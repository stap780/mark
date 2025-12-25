class IncasesController < ApplicationController
  include ActionView::RecordIdentifier
  
  before_action :set_incase, only: [:show, :update_status, :destroy]

  def index
    @search = current_account.incases.includes(:client, :webform).ransack(params[:q])
    @search.sorts = "created_at desc" if @search.sorts.empty?
    @incases = @search.result(distinct: true).paginate(page: params[:page], per_page: 50)
    @webforms = current_account.webforms.order(:title)
  end

  def show; end

  def update_status
    respond_to do |format|
      if @incase.update(status: params.require(:status))
        format.turbo_stream do
          flash.now[:success] = t('.success')
          render turbo_stream: [
            turbo_stream.update(dom_id(current_account, dom_id(@incase, :status)), partial: "incases/status", locals: { incase: @incase }),
            render_turbo_flash
          ]
        end
        format.html { redirect_to account_incase_path(current_account, @incase), notice: 'Status updated' }
      else
        format.turbo_stream do
          flash.now[:alert] = @incase.errors.full_messages.join(', ')
          render turbo_stream: [render_turbo_flash]
        end
        format.html { redirect_to account_incase_path(current_account, @incase), alert: @incase.errors.full_messages.join(', ') }
      end
    end
  end

  def destroy
    @incase.destroy!
    check_destroy = @incase.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t(".success")
    else
      flash.now[:notice] = @incase.errors.full_messages.join(" ")
    end

    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(current_account, dom_id(@incase))),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to account_incases_path(current_account), notice: t('.success') }
      format.json { head :no_content }
    end
  end

  private

  def set_incase
    @incase = current_account.incases.find(params[:id])
  end
  
end


