class InsalesController < ApplicationController
  # Webhook endpoint must be callable without session
  # allow_unauthenticated_access only: [:order]
  before_action :set_insale, only: %i[ show edit update destroy ]
  # Ensure these actions are rendered within a Turbo Frame withount url /new or etc
  before_action :ensure_turbo_frame_response, only: %i[new edit show]
  include ActionView::RecordIdentifier
  
  def index
    @insales = current_account&.insales&.all || Insale.none
  end

  def show; end

  def new
    if current_account&.insales&.exists?
      respond_to do |format|
        notice = 'у вас уже есть интеграция'
        flash.now[:notice] = notice
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash }
        format.html { redirect_to account_insales_path(current_account), notice: notice }
      end
    else
      @insale = current_account.insales.new
    end
  end

  def edit; end

  def create
    @insale = current_account.insales.new(insale_params)

    respond_to do |format|
      if @insale.save
        flash.now[:success] = t('.success', default: 'Insale was successfully created')
        format.turbo_stream { 
          render turbo_stream: turbo_close_offcanvas_flash + [ turbo_stream.update(:insales_actions, partial: "insales/actions", locals: { insale: @insale }) ]
        }
        format.html { redirect_to account_insale_url(current_account, @insale), notice: t('.success', default: 'Insale was successfully created') }
        format.json { render :show, status: :created, location: @insale }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @insale.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @insale.update(insale_params)
        flash.now[:success] = t('.success', default: 'Insale was successfully updated')
        format.turbo_stream { 
          # render turbo_stream: turbo_close_offcanvas_flash + [ turbo_stream.replace([current_account, "insales"], target:  dom_id(@insale), partial: "insales/insale") ]
          render turbo_stream: [
            render_turbo_flash,
            turbo_stream.update(:offcanvas, ""),
            turbo_stream.replace(
              dom_id(@insale),
              partial: "insales/insale",
              locals: { insale: @insale }
              )
          ]
        }
        format.html { redirect_to account_insale_url(current_account, @insale), notice: t('.success', default: 'Insale was successfully updated') }
        format.json { render :show, status: :ok, location: @insale }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @insale.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @insale.destroy!

    respond_to do |format|
      flash.now[:success] = t('.success', default: 'Insale was successfully destroyed')
      format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [ turbo_stream.update(:insales_actions, partial: "insales/actions") ] }
      format.html { redirect_to account_insales_path(current_account), notice: t('.success', default: 'Insale was successfully destroyed') }
      format.json { head :no_content }
    end
  end

  def check
    result, message = Insale.api_work?
    respond_to do |format|
      if result
        flash.now[:success] = t('.success', default: 'API work')
      else
        flash.now[:error] = Array(message).join(', ')
      end
      format.turbo_stream { render turbo_stream: [ render_turbo_flash ] }
      format.html { redirect_to account_insales_path(account_id: current_account) }
    end
  end

  def add_order_webhook
    result, message = Insale.add_order_webhook
    respond_to do |format|
      if result
        flash.now[:success] = t('.success', default: 'Webhook added')
      else
        flash.now[:error] = Array(message).join(', ')
      end
      format.turbo_stream { render turbo_stream: [ render_turbo_flash ] }
      format.html { redirect_to account_insales_path(account_id: current_account) }
    end
  end

  def create_xml
    result, message = Insale.create_xml
    respond_to do |format|
      if result
        flash.now[:success] = t('.success', default: 'Products XML generated')
      else
        flash.now[:error] = Array(message).join(', ')
      end
      format.turbo_stream { render turbo_stream: [ render_turbo_flash ] }
      format.html { redirect_to account_insales_path(account_id: current_account) }
      format.json { render json: { ok: result, message: message }, status: (result ? :ok : :unprocessable_entity) }
    end
  end

  # Offcanvas to choose XML source: generate automatically or set a custom URL
  def xml_source
    @current_xml = current_account&.insales&.first&.product_xml
    render partial: 'insales/xml_source', layout: false
  end

  # Save a custom XML URL provided by the user
  def set_product_xml
    rec = current_account&.insales&.first
    respond_to do |format|
      if rec.update(product_xml: params[:product_xml])
        flash.now[:success] = t('.success', default: 'Products XML link saved')
      else
        flash.now[:error] = rec.errors.full_messages.to_sentence
      end
      format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash }
      format.html { redirect_to account_insales_path(current_account) }
    end
  end

  # Webhook receiver
  def order
    # In production, verify signature if required by Insales
    InsaleOrderImportJob.perform_later(params.permit!.to_h)
    head :ok
  end

  # Lightweight search through the saved products XML (YML/Marketplace format)
  def products_search
    require 'open-uri'
    query = params[:q].to_s.strip.downcase
    rec = current_account&.insales&.first
    return render json: [] unless rec&.product_xml.present?

    doc = Nokogiri::XML(URI.open(rec.product_xml))
    items = []
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
      items << { offer_id: offer_id, group_id: group_id, title: title, image_link: image, price: price }
      break if items.size >= 20
    end
    render json: items
  end

  # Account-level items picker offcanvas
  def items_picker
    render partial: 'insales/items_picker', layout: false
  end

  private

  def ensure_turbo_frame_response
    redirect_to account_insales_path(current_account) unless turbo_frame_request?
  end

  def set_insale
    @insale = current_account.insales.find(params[:id])
  end

  def insale_params
    params.require(:insale).permit(:api_key, :api_password, :api_link, :swatch_file)
  end
end
