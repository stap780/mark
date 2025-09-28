class SwatchGroupsController < ApplicationController
  before_action :set_swatch_group, only: %i[ show edit update destroy preview toggle_status ]

  def index
    @swatch_groups = current_account.swatch_groups.ordered
  end

  def show
    @assigned_products = @swatch_group.swatch_group_products.includes(:product).ordered
    @available_products = current_account.products.order(:title)
  end

  def new
    @swatch_group = current_account.swatch_groups.new
    @available_products = current_account.products.order(:title)
  end

  def edit
    @available_products = current_account.products.order(:title)
  end

  def create
    @swatch_group = current_account.swatch_groups.new(swatch_group_params.except(:selected_items))
    if @swatch_group.save
      persist_selected_items(@swatch_group, swatch_group_params[:selected_items])
      SwatchJsonGeneratorJob.perform_later(current_account.id)
      redirect_to account_swatch_groups_path(current_account), notice: "Swatch group created."
    else
      @available_products = current_account.products.order(:title)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @swatch_group.update(swatch_group_params.except(:selected_items))
      persist_selected_items(@swatch_group, swatch_group_params[:selected_items])
      SwatchJsonGeneratorJob.perform_later(current_account.id)
      redirect_to account_swatch_groups_path(current_account), notice: "Swatch group updated."
    else
      @available_products = current_account.products.order(:title)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @swatch_group.destroy
    SwatchJsonGeneratorJob.perform_later(current_account.id)
    redirect_to account_swatch_groups_path(current_account), notice: "Swatch group deleted."
  end

  def preview
    render layout: false
  end

  def toggle_status
    @swatch_group.update(status: @swatch_group.active? ? "inactive" : "active")
    redirect_to account_swatch_groups_path(current_account), notice: "Swatch group #{@swatch_group.status}."
  end

  def regenerate_json
    SwatchJsonGeneratorJob.perform_later(current_account.id)
    redirect_to account_swatch_groups_path(current_account), notice: "JSON regeneration started."
  end

  # Offcanvas for selecting a style for either field
  def style_selector
    @field = params[:field].in?(%w[product_page_style collection_page_style]) ? params[:field] : "product_page_style"
    @current_value = params[:current]
    render partial: "swatch_groups/style_selector", locals: { field: @field, current_value: @current_value }, layout: false
  end

  # Offcanvas products picker that searches via product_xml
  def products_picker
    @swatch_group = current_account.swatch_groups.find(params[:id])
    render partial: "swatch_group_products/picker", layout: false
  end

  private

  def set_swatch_group
    @swatch_group = current_account.swatch_groups.find(params[:id])
  end

  def swatch_group_params
    params.require(:swatch_group).permit(:name, :option_name, :status, :product_page_style, :collection_page_style, :swatch_image_source, selected_items: [:offer_id, :title, :image_link, :price])
  end

  # Create/update Product/Variant/Varbind and SwatchGroupProduct for bucketed items
  def persist_selected_items(group, selected)
    return if selected.blank?

    selected.values.each do |item|
      title = item["title"]
      offer_id = item["offer_id"]
      insales_file_product_id = item["group_id"]
      image = item["image_link"]
      price = item["price"].presence
      next if offer_id.blank? || title.blank?

      product = current_account.products.find_or_initialize_by(title: title)
      product.save! if product.changed?

      # Link variant via Insale varbind when available
      insale = current_account.insales.first
      existing_bind = insale ? Varbind.find_by(varbindable: insale, value: offer_id) : nil
      variant = existing_bind&.variant
      variant ||= product.variants.joins(:varbinds).find_by(varbinds: { value: offer_id })
      variant ||= product.variants.first_or_initialize
      variant.image_link ||= image
      variant.price = price if price.present?
      variant.save! if variant.changed?

      Varbind.find_or_create_by!(variant: variant, varbindable: (insale || group), value: offer_id)

      group.swatch_group_products.find_or_create_by!(product: product) do |sgp|
        sgp.swatch_value = insales_file_product_id
      end
    end
  end
end
