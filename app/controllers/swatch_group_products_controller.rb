class SwatchGroupProductsController < ApplicationController
  before_action :set_swatch_group
  before_action :set_swatch_group_product, only: %i[ new edit update destroy sort ]
  include ActionView::RecordIdentifier

  def new
    group_id = params[:group_id]
    offer_id = params[:offer_id]
    title = params[:title]
    image_link = params[:image_link]
    swatch_value = [group_id, offer_id].compact.join("#")
    @sgp = SwatchGroupProduct.new(title: title, swatch_value: swatch_value, color: nil, product_id: nil, image_link: image_link)

    @target = dom_id(current_account, :swatch_group_products)
    # puts "new @target => #{@target.inspect}"
    respond_to do |format|
      format.turbo_stream
    end
  end

  def edit
  end

  def create
    # If an external offer id is provided, find or create a local Product for this account
    if params[:external_offer_id].present?
      # Find or create Product (title only), then a Variant bound to the external offer id
      product = current_account.products.find_or_initialize_by(title: params[:external_title].presence || "Product")
      product.image_link ||= params[:external_image]
      product.save! if product.changed?

      offer_id = params[:external_offer_id]
      price = params[:external_price].presence
      insale = current_account.insales.first

      # Try find existing variant linked by Insale varbind value
      variant = nil
      if insale
        existing_bind = Varbind.find_by(varbindable: insale, value: offer_id)
        variant = existing_bind&.record
      end
      # Fallback: find any variant for this product with matching varbind value regardless of type
      variant ||= product.variants.joins(:varbinds).find_by(varbinds: { value: offer_id })

      unless variant
        variant = product.variants.create!
        Varbind.create!(record: variant, varbindable: (insale || @swatch_group), value: offer_id)
      end

      # Update variant info
      variant.image_link ||= params[:external_image]
      variant.price = price if price.present?
      variant.save! if variant.changed?

      params[:swatch_group_product] ||= {}
      params[:swatch_group_product][:product_id] = product.id
    end

    @sgp = @swatch_group.swatch_group_products.build(sgp_params)
    respond_to do |format|
      if @sgp.save
        flash.now[:success] = t("controllers.swatch_group_products.create.success")
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash }
        format.html { redirect_to account_swatch_group_path(current_account, @swatch_group), notice: t("controllers.swatch_group_products.create.success") }
      else
        flash.now[:error] = @sgp.errors.full_messages.to_sentence
        format.turbo_stream { render turbo_stream: [ render_turbo_flash ] }
        format.html { redirect_to account_swatch_group_path(current_account, @swatch_group), alert: @sgp.errors.full_messages.to_sentence }
      end
    end
  end

  def update
    if @sgp.update(sgp_params)
      redirect_to account_swatch_group_path(current_account, @swatch_group), notice: t("controllers.swatch_group_products.update.success")
    else
      redirect_to account_swatch_group_path(current_account, @swatch_group), alert: @sgp.errors.full_messages.to_sentence
    end
  end

  def destroy
    @target = "swatch_group_product_"+params[:id]
    puts "destroy @target => #{@target.inspect}"
    @sgp.destroy
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.remove(@target),
          render_turbo_flash
        ]
      }
    end
  end

  def sort
    @sgp.update(position: params[:position])
    head :ok
  end

  private

  def set_swatch_group
    @swatch_group = current_account.swatch_groups.find(params[:swatch_group_id])
    rescue ActiveRecord::RecordNotFound
      @swatch_group = current_account.swatch_groups.new(id: params[:swatch_group_id])
  end

  def set_swatch_group_product
    @sgp = @swatch_group.swatch_group_products.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      @sgp = @swatch_group.swatch_group_products.new
  end

  def sgp_params
    params.require(:swatch_group_product).permit(:product_id, :swatch_label, :swatch_value, :color, :title, :image_link, :image)
  end
end