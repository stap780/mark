class Admin::AccountsController < ApplicationController
  include ActionView::RecordIdentifier
  
  skip_before_action :ensure_user_in_current_account
  before_action :ensure_super_admin_account
  before_action :set_account, only: %i[show edit update destroy]

  def index
    @search = Account.ransack(params[:q])
    @search.sorts = "id desc" if @search.sorts.empty?
    @accounts = @search.result
  end


  def show
    @account_users = @account.account_users.includes(:user).order('users.email_address')
  end

  def new
    @account = Account.new
  end

  def edit
  end

  def create
    @account = Account.new(account_params)

    respond_to do |format|
      if @account.save
        message = t(".success", default: 'Account was successfully created')
        flash.now[:success] = message
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append("accounts_list", partial: "admin/accounts/account", locals: { account: @account })
          ]
        end
        format.html { redirect_to admin_account_path(@account), notice: message }
        format.json { render :show, status: :created, location: admin_account_path(@account) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @account.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @account.update(account_params)
        message = t('.success', default: 'Account was successfully updated')
        flash.now[:success] = message
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(dom_id(@account), partial: "admin/accounts/account", locals: { account: @account })
          ]
        end
        format.html { redirect_to admin_account_path(@account), notice: message, status: :see_other }
        format.json { render :show, status: :ok, location: admin_account_path(@account) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @account.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    user_accounts = Current.session&.user&.accounts || []
    if @account.admin? && user_accounts.include?(@account)
      flash.now[:error] = t('.cannot_delete_self', default: 'You cannot delete your own admin account')
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [render_turbo_flash]
        end
        format.html { redirect_to admin_accounts_path }
        format.json { head :no_content }
      end
    else
      begin
        @account.destroy
        flash.now[:success] = t('.success', default: 'Account was successfully deleted')

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              render_turbo_flash,
              turbo_stream.remove(dom_id(@account))
            ]
          end
          format.html { redirect_to admin_accounts_path, notice: t('.success') }
          format.json { head :no_content }
        end
      rescue ActiveRecord::InvalidForeignKey => e
        error_message = if e.message.include?('users')
          t('.cannot_delete_with_users', default: 'Cannot delete account because it has users. Please delete all users first.')
        else
          t('.cannot_delete', default: 'Cannot delete account because it has associated records.')
        end
        
        flash.now[:error] = error_message
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [render_turbo_flash]
          end
          format.html { redirect_to admin_accounts_path, alert: error_message }
          format.json { render json: { error: error_message }, status: :unprocessable_entity }
        end
      end
    end
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :admin)
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
