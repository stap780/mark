class UsersController < ApplicationController
  before_action :set_user, only: %i[ show edit update destroy ]
  before_action :ensure_admin, only: %i[ new create edit update destroy ]

  def index
    @users = current_account.users.order(:email_address)
  end

  def show
  end

  def new
    @user = current_account.users.new
  end

  def edit
  end

  def create
    @user = current_account.users.new(user_params)

    respond_to do |format|
      if @user.save
        message = t(".success", default: 'User was successfully created')
        flash.now[:success] = message
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash
        }
        format.html { redirect_to account_user_path(current_account, @user), notice: message }
        format.json { render :show, status: :created, location: account_user_path(current_account, @user) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @user.update(user_params)
        message = t('.success', default: 'User was successfully updated')
        flash.now[:success] = message
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash
        }
        format.html { redirect_to account_user_path(current_account, @user), notice: message, status: :see_other }
        format.json { render :show, status: :ok, location: account_user_path(current_account, @user) }
      else
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
    params.require(:user).permit(:email_address, :password, :password_confirmation, :role)
  end

  def ensure_admin
    unless Current.user&.admin?
      flash[:error] = t('users.access_denied', default: 'Access denied. Admin privileges required.')
      redirect_to account_users_path(current_account)
    end
  end
end
