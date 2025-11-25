class ClientsController < ApplicationController
  before_action :set_client, only: %i[ show edit update insales_info destroy ]
  include ActionView::RecordIdentifier
  
  def index
    @search = current_account.clients.ransack(params[:q])
    @search.sorts = "id desc" if @search.sorts.empty?
    @clients = @search.result(distinct: true).paginate(page: params[:page], per_page: 50)
  end

  def show
  end

  def new
    @client = current_account.clients.new
  end

  # GET /clients/1/edit
  def edit
  end

  def create
    @client = current_account.clients.new(client_params)

    respond_to do |format|
      if @client.save
        flash.now[:success] = t('.success')
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash
        }
        format.html { redirect_to account_client_path(current_account, @client), notice: t('.success') }
        format.json { render :show, status: :created, location: account_client_path(current_account, @client) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @client.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @client.update(client_params)
        flash.now[:success] = t('.success')
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash
        }
        format.html { redirect_to account_client_path(current_account, @client), notice: t('.success'), status: :see_other }
        format.json { render :show, status: :ok, location: account_client_path(current_account, @client) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @client.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @client.destroy!

    respond_to do |format|
      format.html { redirect_to account_clients_path(current_account), notice: t('.success'), status: :see_other }
      format.json { head :no_content }
    end
  end

  def insales_info
    check  = @client.insale_api_update
    respond_to do |format|
      format.turbo_stream do
        if check
          flash.now[:success] = t(".success")
          render turbo_stream: [
            turbo_stream.replace(dom_id(@client, dom_id(current_account)), 
                partial: "clients/client", 
                locals: { client: @client, current_account: current_account }),
            render_turbo_flash
          ]
        else
          flash.now[:notice] = check
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
    end
  end

  private
  
    def set_client
      @client = current_account.clients.find(params[:id])
    end

    def client_params
      params.require(:client).permit(:name, :surname, :email, :phone, :ya_client)
    end
end
