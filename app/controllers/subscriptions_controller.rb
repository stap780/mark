class SubscriptionsController < ApplicationController
  include ActionView::RecordIdentifier
  include OffcanvasResponder

  before_action :ensure_account_admin
  before_action :set_subscription, only: [:show, :edit, :update, :destroy, :cancel]

  def index
    @subscriptions = current_account.subscriptions.order(created_at: :desc).paginate(page: params[:page], per_page: 50)
  end

  def new
    @subscription = current_account.subscriptions.new
  end

  def create
    @subscription = current_account.subscriptions.new(subscription_params)

    respond_to do |format|
      if @subscription.save
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.prepend(
              dom_id(current_account, :subscriptions),
              partial: "subscriptions/subscription",
              locals: { subscription: @subscription }
            )
          ]
        end
        format.html { redirect_to account_subscription_path(current_account, @subscription), notice: t('.success') }
        format.json { render :show, status: :created, location: account_subscription_path(current_account, @subscription) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @subscription.errors, status: :unprocessable_entity }
      end
    end
  end

  def show; end

  def edit; end

  def update
    
    respond_to do |format|
      if @subscription.update(subscription_params)
        flash.now[:success] = t('.success', default: 'Subscription updated successfully')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(current_account, dom_id(@subscription)),
              partial: "subscriptions/show",
              locals: { subscription: @subscription, payments: @subscription.payments.order(created_at: :desc) }
            )
          ]
        end
        format.html { redirect_to account_subscription_path(current_account, @subscription), notice: t('.success') }
        format.json { render :show, status: :ok, location: account_subscription_path(current_account, @subscription) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @subscription.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @subscription.status == 'active'
      flash.now[:error] = t('.forbidden', default: 'Active subscription cannot be destroyed')
      check_destroy = false
    else
      check_destroy = @subscription.destroy
      flash.now[:success] = t('.success', default: 'Subscription destroyed') if check_destroy
      flash.now[:notice]  = @subscription.errors.full_messages.join(' ') unless check_destroy
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(current_account, dom_id(@subscription))),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to account_subscriptions_path(current_account) }
      format.json { head :no_content }
    end
  end

  def cancel
    if @subscription.status == 'active'
      flash.now[:error] = t('.forbidden')
      ok = false
    else
      Subscription.transaction do
        @subscription.update!(status: :canceled)
        # Все незавершённые платежи по этой подписке считаем несостоявшимися
        @subscription.payments.where(status: :pending).update_all(status: Payment.statuses[:failed])
      end
      flash.now[:success] = t('.success', default: 'Subscription canceled successfully')
      ok = true
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          (ok ? turbo_stream.replace(dom_id(current_account, dom_id(@subscription)), partial: 'subscriptions/subscription', locals: { subscription: @subscription }) : nil),
          render_turbo_flash
        ].compact
      end
      format.html { redirect_to account_subscriptions_path(current_account) }
      format.json { head ok ? :ok : :unprocessable_entity }
    end
  end

  private

  def set_subscription
    @subscription = current_account.subscriptions.find(params[:id])
  end

  def subscription_params
    params.require(:subscription).permit(:account_id, :plan_id, :status, :current_period_start, :current_period_end)
  end

end