class Admin::PlansController < ApplicationController
  include ActionView::RecordIdentifier

  skip_before_action :ensure_user_in_current_account
  before_action :ensure_super_admin_account
  before_action :set_plan, only: [:show, :edit, :update, :destroy]

  def index
    @plans = Plan.order(:name).paginate(page: params[:page], per_page: 50)
  end

  def show; end

  def new
    @plan = Plan.new
  end

  def create
    @plan = Plan.new(plan_params)

    respond_to do |format|
      if @plan.save
        flash.now[:success] = t('.success', default: 'Plan was successfully created')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append("admin_plans", partial: "admin/plans/plan", locals: { plan: @plan })
          ]
        end
        format.html { redirect_to admin_plan_path(@plan), notice: t('.success') }
        format.json { render :show, status: :created, location: admin_plan_path(@plan) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @plan.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @plan.update(plan_params)
        flash.now[:success] = t('.success', default: 'Plan was successfully updated')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(dom_id(@plan), partial: "admin/plans/plan", locals: { plan: @plan })
          ]
        end
        format.html { redirect_to admin_plan_path(@plan), notice: t('.success') }
        format.json { render :show, status: :ok, location: admin_plan_path(@plan) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @plan.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @plan.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @plan.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@plan)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to admin_plans_path, notice: t('.success') }
      format.json { head :no_content }
    end
  end

  private

  def set_plan
    @plan = Plan.find(params[:id])
  end

  def plan_params
    params.require(:plan).permit(:name, :price, :interval, :active, :trial_days)
  end

  def ensure_super_admin_account
    user_accounts = Current.session&.user&.accounts || []
    admin_account = user_accounts.find { |acc| acc.admin? }
    unless admin_account
      flash[:error] = t('accounts.access_denied', default: 'Access denied. Admin account privileges required.')
      if user_accounts.any?
        redirect_to account_dashboard_path(user_accounts.first)
      else
        redirect_to root_path
      end
    end
  end
end

