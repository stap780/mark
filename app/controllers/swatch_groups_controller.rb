
class SwatchGroupsController < ApplicationController
  before_action :set_swatch_group, only: %i[ show edit update destroy preview toggle_status items_picker search]

  def index
    # @swatch_groups = current_account.swatch_groups.ordered
    @search = current_account.swatch_groups.ransack(params[:q])
    @search.sorts = "id desc" if @search.sorts.empty?
    @swatch_groups = @search.result(distinct: true).paginate(page: params[:page], per_page: 50)
  end

  def show
    @assigned_products = @swatch_group.swatch_group_products.includes(:product).ordered
  end

  def new
    @swatch_group = current_account.swatch_groups.new
  end

  def edit
  end

  def create
    @swatch_group = current_account.swatch_groups.new(swatch_group_params)
    if @swatch_group.save
      resolve_products_for_nested(@swatch_group)
      SwatchJsonGeneratorJob.perform_later(current_account.id)
      redirect_to account_swatch_groups_path(current_account), notice: "Swatch group created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @swatch_group.update(swatch_group_params)
      resolve_products_for_nested(@swatch_group)
      SwatchJsonGeneratorJob.perform_later(current_account.id)
      redirect_to account_swatch_groups_path(current_account), notice: "Swatch group updated."
    else
      respond_to do |format|
        flash.now[:notice] = @swatch_group.errors.full_messages.uniq.to_sentence
        format.turbo_stream { render turbo_stream: render_turbo_flash }
        format.html { render :edit, status: :unprocessable_content }
      end
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

  # Turbo: user picks a style; respond with turbo_stream to update a frame in the form
  def pick_style
    @field = params[:field].to_s
    @value = params[:value].to_s
    @label = SwatchGroup.style_label_for(@value) || @value
    render turbo_stream: [
      turbo_stream.replace(
        "style_#{@field}",
        partial: "swatch_groups/style_field",
        locals: { field: @field, value: @value, label: @label }
      ),
      turbo_stream.update(:offcanvas, "")
    ]
  end

  # Account-level items picker offcanvas
  def items_picker
    # puts "items_picker params => #{params.inspect}"
    # puts "items_picker @swatch_group => #{@swatch_group.inspect}"
  end

  # Turbo search endpoint replacing InsalesController#products_search
  def search
    require 'open-uri'
    query = params[:q].to_s.strip.downcase
    rec = current_account&.insales&.first
    @items = []
    if rec&.product_xml.present?
      doc = Nokogiri::XML(URI.open(rec.product_xml))
      doc.xpath('//offer').each do |node|
        offer_id = node['id'] || node.at('id')&.text
        title = node.at('model')&.text.to_s
        image = node.at('picture')&.text
        group_id = node.at('group_id')&.text || node['group_id']
        price_text = node.at('price')&.text
        price_value = price_text.to_s.strip
        price = price_value.present? ? price_value.to_d : nil
        next if title.blank?
        next if query.present? && !title.downcase.include?(query)
        @items << { offer_id: offer_id, group_id: group_id, title: title, image_link: image, price: price }
        break if @items.size >= 20
      end
    end
  end

  private

  def set_swatch_group
    @swatch_group = current_account.swatch_groups.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      @swatch_group = current_account.swatch_groups.new(id: params[:id])
  end

  def swatch_group_params
    params.require(:swatch_group).permit(
      :name, :option_name, :status, :product_page_style, :collection_page_style, :swatch_image_source,
      swatch_group_products_attributes: [:id, :product_id, :swatch_label, :swatch_value, :title, :color, :image_link, :image, :_destroy]
    )
  end

  # After nested params saved, resolve products for any SGPs missing product_id based on swatch_value/title and varbinds
  def resolve_products_for_nested(group)
    puts "resolve_products_for_nested group => #{group.inspect}"
    group.swatch_group_products.each do |sgp|
      next if sgp.product_id.present?

      # Parse swatch_value: "group_id#offer_id" format
      swatch_parts = sgp.swatch_value.to_s.split("#")
      group_id = swatch_parts[0]
      offer_id = swatch_parts[1]

      title = sgp.title.presence
      image_link = sgp.image_link.presence
      next if group_id.blank? || offer_id.blank? || title.blank?

      insale = current_account.insales.first

      # Look for existing product by group_id varbind
      product_bind = insale ? Varbind.find_by(varbindable: insale, value: group_id, record_type: 'Product') : nil
      product = product_bind&.record

      # Look for existing variant by offer_id varbind
      variant_bind = insale ? Varbind.find_by(varbindable: insale, value: offer_id, record_type: 'Variant') : nil
      variant = variant_bind&.record

      # If no product found by varbind, create new one
      unless product
        product = current_account.products.create!(title: title)
      end

      # If no variant found by varbind, create new one
      unless variant
        variant = product.variants.create!(image_link: image_link)
      end

      # Create varbind for variant (offer_id)
      Varbind.find_or_create_by!(record: variant, varbindable: (insale || group), value: offer_id)

      # Create varbind for product (group_id)
      Varbind.find_or_create_by!(record: product, varbindable: (insale || group), value: group_id)

      # Safely set product_id, but skip if it would violate unique index (swatch_group_id, product_id)
      begin
        # Skip if target pair already exists on another row
        if SwatchGroupProduct.exists?(swatch_group_id: group.id, product_id: product.id)
          Rails.logger.info("[resolve_products_for_nested] skip duplicate pair sg=#{group.id} product=#{product.id} for sgp=#{sgp.id}")
          next
        end
        sgp.update!(product_id: product.id)
      rescue ActiveRecord::RecordNotUnique
        Rails.logger.warn("[resolve_products_for_nested] unique violation for sg=#{group.id} product=#{product.id} on sgp=#{sgp.id}; skipping update")
        next
      end
    end
  end
end
