class VariantsController < ApplicationController
  before_action :set_product
  before_action :set_variant, only: %i[ show edit update destroy ]

  def index
    @variants = @product.variants.order(id: :desc)
  end

  def show; end

  def new
    @variant = @product.variants.new
  end

  def edit; end

  def create
    @variant = @product.variants.new(variant_params)

    respond_to do |format|
      if @variant.save
        flash.now[:success] = t(".success")
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash }
        format.html { redirect_to variant_url(@variant), notice: t(".success") }
        format.json { render :show, status: :created, location: @variant }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @variant.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @variant.update(variant_params)
        flash.now[:success] = t(".success")
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash }
        format.html { redirect_to account_product_variant_path(current_account, @product, @variant), notice: t(".success") }
        format.json { render :show, status: :ok, location: @variant }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @variant.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @variant.destroy
    redirect_to account_product_variants_path(current_account, @product), notice: 'Variant deleted.'
  end

  private

  def set_product
    @product = current_account.products.find(params[:product_id])
  end

  def set_variant
    @variant = @product.variants.find(params[:id])
  end

  def variant_params
    params.require(:variant).permit(:barcode, :sku, :price, :image_link)
  end
end


