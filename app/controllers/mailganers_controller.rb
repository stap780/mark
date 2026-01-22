class MailganersController < ApplicationController
  before_action :set_mailganer, only: %i[show edit update destroy test_email_form test_email]
  include ActionView::RecordIdentifier

  def index
    @mailganer = current_account.mailganer
  end

  def show; end

  def new
    if current_account.mailganer.present?
      respond_to do |format|
        notice = t('.already_exists', default: 'Mailganer settings already exist')
        flash.now[:notice] = notice
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash }
        format.html { redirect_to account_mailganers_path(current_account), notice: notice }
      end
    else
      @mailganer = current_account.build_mailganer
    end
  end

  def edit; end

  def create
    @mailganer = current_account.build_mailganer(mailganer_params)

    respond_to do |format|
      if @mailganer.save
        flash.now[:success] = t('.success', default: 'Mailganer settings saved')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.update(
              :mailganers_actions,
              partial: "mailganers/actions",
              locals: { mailganer: @mailganer }
            ),
            turbo_stream.update(
              dom_id(current_account, "mailganers"),
              partial: "mailganers/index_content",
              locals: { mailganer: @mailganer, current_account: current_account }
            )
          ]
        end
        format.html { redirect_to account_mailganers_path(current_account), notice: t('.success', default: 'Mailganer settings saved') }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @mailganer.update(mailganer_params)
        message = t('.success', default: 'Mailganer settings updated')
        flash.now[:success] = message
        format.turbo_stream do
          render turbo_stream: [
            render_turbo_flash,
            turbo_stream.update(:offcanvas, ""),
            turbo_stream.update(
              :mailganers_actions,
              partial: "mailganers/actions",
              locals: { mailganer: @mailganer }
            ),
            turbo_stream.update(
              dom_id(current_account, "mailganers"),
              partial: "mailganers/index_content",
              locals: { mailganer: @mailganer, current_account: current_account }
            )
          ]
        end
        format.html { redirect_to account_mailganers_path(current_account), notice: message }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @mailganer.destroy!

    respond_to do |format|
      message = t('.success', default: 'Mailganer settings removed')
      flash.now[:success] = message
      format.turbo_stream do
        render turbo_stream: turbo_close_offcanvas_flash + [
          turbo_stream.update(:mailganers_actions, partial: "mailganers/actions"),
          turbo_stream.update(
            dom_id(current_account, "mailganers"),
            partial: "mailganers/index_content",
            locals: { mailganer: nil, current_account: current_account }
          )
        ]
      end
      format.html { redirect_to account_mailganers_path(current_account), notice: message }
    end
  end

  def test_email_form
    # offcanvas с формой для тестового письма
  end

  def test_email
    to_email = params[:test_email]
    unless @mailganer
      success = false
      message = t('mailganers.test_email.no_settings', default: 'Mailganer settings are not configured for this account')
    else
      success, message = @mailganer.send_test_email(to_email)
    end

    respond_to do |format|
      flash.now[success ? :success : :error] = message
      format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [render_turbo_flash] }
      format.html { redirect_to account_mailganers_path(current_account) }
    end
  end

  def info; end

  private

  def set_mailganer
    @mailganer = current_account.mailganer
  end

  def mailganer_params
    params.require(:mailganer).permit(:api_key, :smtp_login, :api_key_web_portal)
  end
end


