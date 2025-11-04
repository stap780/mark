class Admin::UsersController < ApplicationController
  include ActionView::RecordIdentifier
  
  skip_before_action :ensure_user_in_current_account
  before_action :ensure_super_admin_account
  before_action :set_account, except: [:index]
  before_action :set_user, only: %i[edit update destroy]
  def index
    @users = User.order(:email_address)
  end
  
  def new
    @user = @account.users.new
    @account_user = @user.account_users.build(account: @account)
  end
  
  def create
    # Try to find existing user by email. If exists, only create/attach AccountUser with selected role.
    email = params.dig(:user, :email_address)
    role  = params.dig(:user, :account_users_attributes, "0", :role) || params.dig(:user, :account_users_attributes, 0, :role)

    existing_user = email.present? ? User.find_by(email_address: email) : nil

    if existing_user
      # If this user is already in the current account → add error, let unified respond_to handle it
      if @account.account_users.exists?(user: existing_user)
        @user = existing_user
        @user.errors.add(:email_address, :taken, message: 'User already exists in this account')
        saved = false
        account_user_for_view = nil
      else
        @user = existing_user
        account_user = @account.account_users.find_or_initialize_by(user: @user)
        account_user.role = role if role.present?
        saved = account_user.save
        account_user_for_view = account_user
        # Surface validation errors to the form object so shared/errors renders something meaningful
        @user.errors.add(:base, account_user.errors.full_messages.to_sentence) unless saved
      end
    else
      @user = @account.users.build(user_params)
      saved = @user.save
      account_user_for_view = @user.account_users.find_by(account: @account)
    end

    respond_to do |format|
      if saved
        message = t(".success", default: 'User was successfully created')
        flash.now[:success] = message
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              dom_id(@account, :users),
              partial: "admin/accounts/user",
              locals: { account_user: account_user_for_view, account: @account, user: @user }
            )
          ]
        }
        format.html { redirect_to admin_account_path(@account), notice: message }
        format.json { render :show, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def edit
    @account_user = @user.account_users.find_by(account: @account)
  end
  
  def update
    respond_to do |format|
      if @user.update(user_params)
        message = t('.success')
        flash.now[:success] = message
        account_user = @user.account_users.find_by(account: @account)
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@account, dom_id(@user)),
              partial: "admin/accounts/user",
              locals: { account_user: account_user, account: @account, user: @user }
            )
          ]
        }
        format.html { redirect_to admin_account_path(@account), notice: message }
        format.json { render :show, status: :ok }
      else
        logger.debug { "UPDATE params: #{params.to_unsafe_h.inspect}" }
        @account_user = @user.account_users.find_by(account: @account) || @user.account_users.build(account: @account)
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def destroy
    account_user = @user.account_users.find_by(account: @account)
    if account_user
      account_user.destroy
      flash.now[:success] = t('.success')
    end
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.remove(dom_id(@account, dom_id(@user)))
        ]
      end
      format.html { redirect_to admin_account_path(@account), notice: t('.success') }
      format.json { head :no_content }
    end
  end
  
  private
  
  def set_account
    @account = Account.find(params[:account_id])
  end
  
  def set_user
    @user = @account.users.find(params[:id])
  end
  
  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation,
                                 account_users_attributes: [:id, :user_id, :account_id, :role, :_destroy])
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
