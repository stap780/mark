class DiscountsController < ApplicationController
  before_action :set_discount, only: %i[ show edit update destroy sort ]
  include ActionView::RecordIdentifier

  def index
    @discounts = current_account.discounts.order(:position)
  end

  def show
  end

  def new
    @discount = current_account.discounts.new
  end

  def edit
  end

  def create
    @discount = current_account.discounts.new(discount_params)

    respond_to do |format|
      if @discount.save
        message = t(".success")
        flash.now[:success] = message
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash
          # render turbo_stream: turbo_close_offcanvas_flash + [
          #   turbo_stream.append(
          #     dom_id(current_account, :discounts),
          #     partial: "discounts/discount",
          #     locals: { discount: @discount, current_account: current_account }
          #     )
          # ]          
        }
        format.html { redirect_to account_discount_path(current_account, @discount), notice: message }
        format.json { render :show, status: :created, location: account_discount_path(current_account, @discount) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @discount.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @discount.update(discount_params)
        flash.now[:success] = t('.success', default: 'Discount was successfully updated')
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash
        }
        format.html { redirect_to account_discount_path(current_account, @discount), notice: "Discount was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: account_discount_path(current_account, @discount) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @discount.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @discount.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @discount.errors.full_messages.join(" ")
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            # turbo_stream.remove(dom_id(current_account, dom_id(@discount))),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to account_discounts_path(current_account), notice: t('.success')}
      format.json { head :no_content }
    end
  end

  def sort
    @discount.insert_at(params[:position].to_i)
    head :ok
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_discount
      @discount = current_account.discounts.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
  def discount_params
    params.require(:discount).permit(:title, :rule, :move, :shift, :points, :notice, :position)
  end
end
