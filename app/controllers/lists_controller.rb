class ListsController < ApplicationController
  before_action :set_list, only: %i[ show edit update destroy ]

  # GET /lists or /lists.json
  def index
    @lists = current_account.lists.order(created_at: :desc)
  end

  # GET /lists/1 or /lists/1.json
  def show
  end

  # GET /lists/new
  def new
    @list = current_account.lists.new
  end

  def edit
  end

  def create
    @list = current_account.lists.new(list_params)

    respond_to do |format|
      if @list.save
        notice = t(".success", default: "List was successfully created")
        flash.now[:success] = notice
        format.turbo_stream { 
          render turbo_stream: turbo_close_offcanvas_flash
        }
        format.html { redirect_to account_list_path(current_account, @list), notice: notice }
        format.json { render :show, status: :created, location: account_list_path(current_account, @list) }
        ListJsonGeneratorJob.perform_later(current_account.id)
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @list.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @list.update(list_params)
        notice = t(".success", default: "List was successfully updated")
        flash.now[:success] = notice
        format.turbo_stream { 
          render turbo_stream: turbo_close_offcanvas_flash
        }
        format.html { redirect_to account_list_path(current_account, @list), notice: notice, status: :see_other }
        format.json { render :show, status: :ok, location: account_list_path(current_account, @list) }
        ListJsonGeneratorJob.perform_later(current_account.id)
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @list.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @list.destroy!

    respond_to do |format|
      format.html { redirect_to account_lists_path(current_account), notice: "List was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
    ListJsonGeneratorJob.perform_later(current_account.id)
  end

  private
  
    def set_list
      @list = current_account.lists.find(params[:id])
    end

    def list_params
      params.require(:list).permit(:name, :icon_style, :icon_color)
    end
end
