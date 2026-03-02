# frozen_string_literal: true

class InsaleStatusMappingsController < ApplicationController
  include ActionView::RecordIdentifier
  include OffcanvasResponder

  before_action :set_insale
  before_action :set_insale_status_mapping, only: %i[edit update destroy]

  def index
    @insale_status_mappings = @insale.insale_status_mappings.order(:insales_custom_status_permalink, :insales_financial_status)
  end

  def new
    @insale_status_mapping = @insale.insale_status_mappings.build
  end

  def create
    @insale_status_mapping = @insale.insale_status_mappings.build(insale_status_mapping_params)

    if @insale_status_mapping.save
      flash.now[:success] = t(".success")
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(dom_id(@insale, :insale_status_mappings), partial: "insale_status_mappings/insale_status_mapping", locals: { insale_status_mapping: @insale_status_mapping })
          ]
        end
        format.html { redirect_to account_insale_insale_status_mappings_path(current_account, @insale), notice: t(".success") }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(:new_insale_status_mapping_form, partial: "insale_status_mappings/form", locals: { insale_status_mapping: @insale_status_mapping }), status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    if @insale_status_mapping.update(insale_status_mapping_params)
      flash.now[:success] = t(".success")
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(dom_id(@insale_status_mapping), partial: "insale_status_mappings/insale_status_mapping", locals: { insale_status_mapping: @insale_status_mapping })
          ]
        end
        format.html { redirect_to account_insale_insale_status_mappings_path(current_account, @insale), notice: t(".success") }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id(@insale_status_mapping, :form), partial: "insale_status_mappings/form", locals: { insale_status_mapping: @insale_status_mapping }), status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @insale_status_mapping.destroy!
    flash.now[:success] = t(".success")
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(dom_id(@insale_status_mapping)),
          render_turbo_flash
        ]
      end
      format.html { redirect_to account_insale_insale_status_mappings_path(current_account, @insale), notice: t(".success") }
    end
  end

  private

  def set_insale
    @insale = current_account.insales.find(params[:insale_id])
  end

  def set_insale_status_mapping
    @insale_status_mapping = @insale.insale_status_mappings.find(params[:id])
  end

  def insale_status_mapping_params
    params.require(:insale_status_mapping).permit(:insales_custom_status_permalink, :insales_financial_status, :incase_status_id)
  end
end
