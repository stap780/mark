class ListItemsController < ApplicationController
  before_action :set_list_item, only: %i[ show edit update destroy ]
  before_action :set_list, only: %i[index create]

  def index
    base_scope = if @list
      @list.list_items
    else
      ListItem.joins(:list).where(lists: { account_id: current_account.id })
    end
    @q = base_scope.order(created_at: :desc).ransack(params[:q])
    @list_items = @q.result(distinct: true).paginate(page: params[:page], per_page: 50)
  end

  def show
  end

  def new
    @list_item = ListItem.new
  end

  def edit
  end

  def create
    return head :unprocessable_entity unless @list

    # Resolve client by external client_id via varbind
    # client = resolve_client_by_external_id(params[:external_client_id]) if params[:external_client_id]
    client ||= current_account.clients.find(params[:client_id]) if params[:client_id]
    return head :unprocessable_entity unless client

    # Resolve item (Product/Variant) by external IDs via varbind
    # item = resolve_item_by_external_ids(params[:external_product_id], params[:external_variant_id])
    # return head :unprocessable_entity unless item

    # Idempotent find-or-create by unique key (list_id, client_id, item_type, item_id)
    @list_item = @list.list_items.find_by(client_id: client.id, item_type: item.class.name, item_id: item.id)
    @list_item ||= @list.list_items.new(client_id: client.id, item: item)

    respond_to do |format|
      if @list_item.persisted? || @list_item.save
        format.html { redirect_to account_list_path(current_account, @list_item.list), notice: "List item added." }
        format.json do
          status_code = @list_item.previous_changes.present? ? :created : :ok
          render :show, status: status_code, location: account_list_list_items_path(current_account, @list_item.list)
        end
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @list_item.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @list_item.update(list_item_params)
        format.html { redirect_to @list_item, notice: "List item was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @list_item }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @list_item.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @list_item.destroy!

    respond_to do |format|
      format.html { redirect_to account_list_path(current_account, @list_item.list), notice: "List item was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    def set_list_item
      @list_item = @list.list_items.find(params[:id])
    end

    def set_list
      @list = current_account.lists.find(params[:list_id])
    end

    def list_item_params
      params.require(:list_item).permit(:list_id, :item_id, :item_type, :client_id)
    end

  end
