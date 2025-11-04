class UsersController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_user, only: %i[ show edit update destroy ]
  before_action :ensure_admin, only: %i[ new create edit update destroy ]

  def index
    @users = current_account.users.order(:email_address)
  end

  def show
  end

  def new
    @user = current_account.users.new
    current_account_user = @user.account_users.build(account: current_account)
  end

  def edit
    @account_user = @user.account_users.find_by(account: current_account)
  end

  def create
    # Try to find existing user by email. If exists, only create/attach AccountUser with selected role.
    email = params.dig(:user, :email_address)
    role  = params.dig(:user, :account_users_attributes, "0", :role) || params.dig(:user, :account_users_attributes, 0, :role)

    existing_user = email.present? ? User.find_by(email_address: email) : nil

    if existing_user
      # If this user is already in the current account → add error, let unified respond_to handle it
      if current_account.account_users.exists?(user: existing_user)
        @user = existing_user
        @user.errors.add(:email_address, :taken, message: 'User already exists in this account')
        saved = false
        account_user_for_view = nil
      else
        @user = existing_user
        account_user = current_account.account_users.find_or_initialize_by(user: @user)
        account_user.role = role if role.present?
        saved = account_user.save
        account_user_for_view = account_user
        # Surface validation errors to the form object so shared/errors renders something meaningful
        @user.errors.add(:base, account_user.errors.full_messages.to_sentence) unless saved
      end
    else
      @user = current_account.users.build(user_params)
      saved = @user.save
      account_user_for_view = @user.account_users.find_by(account: current_account)
    end

    respond_to do |format|
      if saved
        message = t(".success")
        flash.now[:success] = message
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              dom_id(current_account, :users),
              partial: "users/user",
              locals: { account_user: account_user_for_view, account: current_account, user: @user }
            )
          ]
        }
        format.html { redirect_to admin_account_path(current_account), notice: message }
        format.json { render :show, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @user.update(user_params)
        message = t('.success')
        flash.now[:success] = message
        account_user = @user.account_users.find_by(account: current_account)

        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(current_account, dom_id(@user)),
              partial: "users/user",
              locals: { account_user: account_user, account: current_account, user: @user }
            )
          ]
        }
        format.html { redirect_to account_users_path(current_account), notice: message, status: :see_other }
        format.json { render :show, status: :ok }
      else
        current_account_user = @user.account_users.find_by(account: current_account) || @user.account_users.build(account: current_account)
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    # Нельзя удалить самого себя
    if @user == Current.user
      flash.now[:error] = t('.cannot_delete_self', default: 'You cannot delete your own account')
    else
      @user.destroy
      flash.now[:success] = t('.success', default: 'User was successfully deleted')
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(dom_id(current_account, dom_id(@user))),
          render_turbo_flash
        ]
      end
      format.html { redirect_to account_users_path(current_account), notice: t('.success') }
      format.json { head :no_content }
    end
  end

  private

  def set_user
    @user = current_account.users.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation,
                                 account_users_attributes: [:id, :account_id, :role, :_destroy])
  end

  def ensure_admin
    # Разрешаем доступ если:
    # 1. Пользователь имеет роль admin в текущем аккаунте
    # 2. ИЛИ пользователь принадлежит к супер-админ аккаунту (может управлять любыми аккаунтами)
    unless Current.user&.admin_in_account?(current_account) || Current.user&.accounts&.any? { |acc| acc.admin? }
      flash[:error] = t('users.access_denied', default: 'Access denied. Admin privileges required.')
      redirect_to account_users_path(current_account)
    end
  end

end
