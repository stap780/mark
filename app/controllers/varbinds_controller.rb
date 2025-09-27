class VarbindsController < ApplicationController
  before_action :set_product
  before_action :set_variant
  before_action :set_varbind, only: %i[ show edit update destroy ]

  def index
    @varbinds = @variant.varbinds.order(id: :desc)
    render layout: false if turbo_frame_request?
  end

  def show; end

  def new
    @varbind = @variant.varbinds.new
  end

  def edit; end

  def create
    @varbind = @variant.varbinds.new(varbind_params)
    respond_to do |format|
      if @varbind.save
        flash.now[:success] = t("success")
        format.turbo_stream do
          render turbo_stream: [
            render_turbo_flash
          ]
        end
        format.html { redirect_to account_product_variant_path(current_account, @product, @variant), notice: 'Varbind created.' }
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

  def set_product
    @product = current_account.products.find(params[:product_id])
  end

  def set_variant
    @variant = @product.variants.find(params[:variant_id])
  end

  def set_varbind
    @varbind = @variant.varbinds.find(params[:id])
  end

  def varbind_params
    params.require(:varbind).permit(:varbindable_type, :varbindable_id, :value)
  end
end


