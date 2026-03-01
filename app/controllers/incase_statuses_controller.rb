# frozen_string_literal: true

class IncaseStatusesController < ApplicationController
  include OffcanvasResponder
  include ActionView::RecordIdentifier

  before_action :set_incase_status, only: [:edit, :update, :destroy]

  def index
    @incase_statuses = current_account.incase_statuses.ordered
  end

  def new
    @incase_status = current_account.incase_statuses.build(position: current_account.incase_statuses.maximum(:position).to_i + 1)
  end

  def create
    @incase_status = current_account.incase_statuses.build(incase_status_params)
    if @incase_status.save
      flash.now[:success] = t(".success")
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(dom_id(current_account, :incase_statuses), partial: "incase_statuses/incase_status", locals: { incase_status: @incase_status })
          ]
        end
        format.html { redirect_to account_incase_statuses_path(current_account), notice: t(".success") }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(:new_incase_status_form, partial: "incase_statuses/form", locals: { incase_status: @incase_status }), status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    if @incase_status.update(incase_status_params)
      flash.now[:success] = t(".success")
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(dom_id(@incase_status), partial: "incase_statuses/incase_status", locals: { incase_status: @incase_status })
          ]
        end
        format.html { redirect_to account_incase_statuses_path(current_account), notice: t(".success") }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@incase_status, :form), partial: "incase_statuses/form", locals: { incase_status: @incase_status }), status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @incase_status.destroy
      flash.now[:success] = t(".success")
    else
      flash.now[:error] = @incase_status.errors.full_messages.join(", ")
    end
    respond_to do |format|
      format.turbo_stream { render turbo_stream: [turbo_stream.remove(dom_id(@incase_status)), render_turbo_flash] }
      format.html { redirect_to account_incase_statuses_path(current_account), notice: (flash.now[:success] || flash.now[:error]) }
    end
  end

  private

  def set_incase_status
    @incase_status = current_account.incase_statuses.find(params[:id])
  end

  def incase_status_params
    params.require(:incase_status).permit(:name, :color, :position)
  end
end
