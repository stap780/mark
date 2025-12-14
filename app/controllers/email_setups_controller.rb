class EmailSetupsController < ApplicationController
  before_action :set_email_setup, only: %i[ show edit update destroy test_email test_email_form ]
  include ActionView::RecordIdentifier
  
  def index
    @email_setup = current_account&.email_setup
  end

  def show; end

  def new
    if current_account&.email_setup&.present?
      respond_to do |format|
        notice = t('.already_exists', default: 'Email settings already exist')
        flash.now[:notice] = notice
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash }
        format.html { redirect_to account_email_setups_path(current_account), notice: notice }
      end
    else
      @email_setup = current_account.build_email_setup
    end
  end

  def edit; end

  def create
    @email_setup = current_account.build_email_setup(email_setup_params)

    respond_to do |format|
      if @email_setup.save
        flash.now[:success] = t('.success')
        format.turbo_stream { 
          render turbo_stream: turbo_close_offcanvas_flash + [ 
            turbo_stream.update(
              :email_setups_actions,
              partial: "email_setups/actions",
              locals: { email_setup: @email_setup }
            ),
            turbo_stream.update(
              "email_setups",
              partial: "email_setups/index_content",
              locals: { email_setup: @email_setup, current_account: current_account }
            ) 
          ]
        }
        format.html { redirect_to account_email_setups_path(current_account), notice: t('.success') }
        format.json { render :show, status: :created, location: @email_setup }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @email_setup.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @email_setup.update(email_setup_params)
        message = t('.success')
        flash.now[:success] = message
        format.turbo_stream { 
          render turbo_stream: [
            render_turbo_flash,
            turbo_stream.update(:offcanvas, ""),
            turbo_stream.update(
              :email_setups_actions,
              partial: "email_setups/actions",
              locals: { email_setup: @email_setup }
            ),
            turbo_stream.update(
              "email_setups",
              partial: "email_setups/index_content",
              locals: { email_setup: @email_setup, current_account: current_account }
            )
          ]
        }
        format.html { redirect_to account_email_setups_path(current_account), notice: message }
        format.json { render :show, status: :ok, location: @email_setup }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @email_setup.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @email_setup.destroy!

    respond_to do |format|
      message = t('.success')
      flash.now[:success] = message
      format.turbo_stream { 
        render turbo_stream: turbo_close_offcanvas_flash + [ 
          turbo_stream.update(:email_setups_actions, partial: "email_setups/actions"),
          turbo_stream.update(
            "email_setups",
            partial: "email_setups/index_content",
            locals: { email_setup: nil, current_account: current_account }
          )
        ] 
      }
      format.html { redirect_to account_email_setups_path(current_account), notice: message }
      format.json { head :no_content }
    end
  end

  def test_email_form
    # Открывает offcanvas с формой для тестового письма
  end

  def test_email
    test_email_address = params[:test_email]
    result, message = @email_setup.send_test_email(test_email_address)
    message = result ? t('.success') : t('.error')
    respond_to do |format|
      flash.now[:success] = message
      format.turbo_stream { 
        render turbo_stream: turbo_close_offcanvas_flash
      }
      format.html { redirect_to account_email_setups_path(current_account) }
    end
  end

  private

  def set_email_setup
    @email_setup = current_account.email_setup
  end

  def email_setup_params
    params.require(:email_setup).permit(:address, :port, :domain, :authentication, :user_name, :user_password, :tls)
  end

end

