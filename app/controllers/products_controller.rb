class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit update destroy ]
  include ActionView::RecordIdentifier


  def index
    # @products = current_account.products.includes(:variants).order(:title)
    @search = current_account.products.ransack(params[:q])
    @search.sorts = "id desc" if @search.sorts.empty?
    @products = @search.result(distinct: true).paginate(page: params[:page], per_page: 50)
  end

  def show
    redirect_to edit_account_product_path(current_account, @product)
  end

  def new
    @product = current_account.products.new
  end

  def edit; end

  def create
    @product = current_account.products.new(product_params)
    if @product.save
      redirect_to edit_account_product_path(current_account, @product), notice: 'Product created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @product.update(product_params)
      redirect_to account_products_path(current_account), notice: 'Product updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    check_destroy = @product.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t(".success")
    else
      flash.now[:notice] = @product.errors.full_messages.join(" ")
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@product)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to account_products_path(current_account), notice: t(".success") }
      format.json { head :no_content }
    end
  end

  private

  def set_product
    @product = current_account.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :title,
      variants_attributes: [:id, :sku, :barcode, :price, :image_link, :_destroy]
    )
  end
end


