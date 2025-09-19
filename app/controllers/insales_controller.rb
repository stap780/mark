class InsalesController < ApplicationController
  # Webhook endpoint must be callable without session
  allow_unauthenticated_access only: [:order]
  before_action :set_insale, only: %i[ show edit update destroy ]

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
        format.html { redirect_to account_insales_path(account_id: Current.account), notice: notice }
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
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [ turbo_stream.update(:insales_actions, partial: "insales/actions") ] }
        format.html { redirect_to account_insale_url(account_id: current_account, id: @insale), notice: t('.success', default: 'Insale was successfully created') }
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
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash }
        format.html { redirect_to account_insale_url(account_id: current_account, id: @insale), notice: t('.success', default: 'Insale was successfully updated') }
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
      format.html { redirect_to account_insales_path(account_id: current_account), notice: t('.success', default: 'Insale was successfully destroyed') }
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
      format.turbo_stream { render turbo_stream: [ render_turbo_flash, turbo_stream.replace(:offcanvas_wrap, "") ] }
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
      format.turbo_stream { render turbo_stream: [ render_turbo_flash, turbo_stream.replace(:offcanvas_wrap, "") ] }
      format.html { redirect_to account_insales_path(account_id: current_account) }
    end
  end

  # Webhook receiver
  def order
    # In production, verify signature if required by Insales
    InsaleOrderImportJob.perform_later(params.permit!.to_h)
    head :ok
  end

  private

  def set_insale
    @insale = current_account.insales.find(params[:id])
  end

  def insale_params
    params.require(:insale).permit(:api_key, :api_password, :api_link)
  end
end
