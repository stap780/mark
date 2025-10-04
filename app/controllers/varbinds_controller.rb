class VarbindsController < ApplicationController
  before_action :set_record
  before_action :set_varbind, only: %i[ show edit update destroy ]

  def index
    @varbinds = @record.varbinds.order(id: :desc)
    render layout: false if turbo_frame_request?
  end

  def show; end

  def new
    @varbind = @record.varbinds.new
  end

  def edit; end

  def create
    @varbind = @record.varbinds.new(varbind_params)
    respond_to do |format|
      if @varbind.save
        flash.now[:success] = t("success")
        format.turbo_stream do
          render turbo_stream: [
            render_turbo_flash
          ]
        end
        format.html { redirect_to polymorphic_path([current_account, @record]), notice: 'Varbind created.' }
      else
        format.turbo_stream do
          flash.now[:success] = @varbind.errors.full_messages.join(", ")
          render turbo_stream: [
            render_turbo_flash
          ]
        end
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @varbind.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @varbind.update(varbind_params)
        flash.now[:success] = t("success")
        format.turbo_stream do
          render turbo_stream: [
            render_turbo_flash
          ]
        end
        format.html { redirect_to @varbind, notice: t("success") }
        format.json { render :show, status: :ok, location: @varbind }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @varbind.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @varbind.destroy!

    respond_to do |format|
      flash.now[:success] = t("success")
      format.turbo_stream do
        render turbo_stream: [
          render_turbo_flash
        ]
      end
      format.html { redirect_to varbinds_path, status: :see_other, notice: t('.success') }
      format.json { head :no_content }
    end
  end

  private

  def set_record
    # Support multiple record types: Client, Product, Variant
    if params[:client_id]
      @record = current_account.clients.find(params[:client_id])
    elsif params[:product_id]
      @record = current_account.products.find(params[:product_id])
      if params[:variant_id]
        @record = @record.variants.find(params[:variant_id])
      end
    else
      head :not_found
    end
  end

  def set_varbind
    @varbind = @record.varbinds.find(params[:id])
  end

  def varbind_params
    params.require(:varbind).permit(:varbindable_type, :varbindable_id, :value)
  end
end


