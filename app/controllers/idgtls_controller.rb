class IdgtlsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_idgtl, only: %i[show edit update destroy test_sms_form test_sms]

  def index
    @idgtl = current_account.idgtl
  end

  def show; end

  def new
    if current_account.idgtl.present?
      respond_to do |format|
        notice = t(".already_exists")
        flash.now[:notice] = notice
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash }
        format.html { redirect_to account_idgtls_path(current_account), notice: notice }
      end
    else
      @idgtl = current_account.build_idgtl
    end
  end

  def edit; end

  def create
    @idgtl = current_account.build_idgtl(idgtl_params)

    respond_to do |format|
      if @idgtl.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.update(
              :idgtls_actions,
              partial: "idgtls/actions",
              locals: { idgtl: @idgtl }
            ),
            turbo_stream.update(
              "idgtls",
              partial: "idgtls/index_content",
              locals: { idgtl: @idgtl, current_account: current_account }
            )
          ]
        end
        format.html { redirect_to account_idgtls_path(current_account), notice: t(".success") }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @idgtl.update(idgtl_params)
        message = t(".success")
        flash.now[:success] = message
        format.turbo_stream do
          render turbo_stream: [
            render_turbo_flash,
            turbo_stream.update(:offcanvas, ""),
            turbo_stream.update(
              :idgtls_actions,
              partial: "idgtls/actions",
              locals: { idgtl: @idgtl }
            ),
            turbo_stream.update(
              "idgtls",
              partial: "idgtls/index_content",
              locals: { idgtl: @idgtl, current_account: current_account }
            )
          ]
        end
        format.html { redirect_to account_idgtls_path(current_account), notice: message }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @idgtl.destroy!

    respond_to do |format|
      message = t(".success", default: "i-dgtl settings removed")
      flash.now[:success] = message
      format.turbo_stream do
        render turbo_stream: turbo_close_offcanvas_flash + [
          turbo_stream.update(:idgtls_actions, partial: "idgtls/actions"),
          turbo_stream.update(
            "idgtls",
            partial: "idgtls/index_content",
            locals: { idgtl: nil, current_account: current_account }
          )
        ]
      end
      format.html { redirect_to account_idgtls_path(current_account), notice: message }
    end
  end

  def test_sms_form; end

  def test_sms
    phone = params[:test_phone].to_s
    text = params[:test_text].presence || "Test SMS from i-dgtl settings for account ##{current_account.id}"

    success = false
    message = t("idgtls.test_sms.error")

    if @idgtl.present?
      client = SmsProviders::IdgtlClient.new(token_1: @idgtl.token_1)
      result = client.send_sms!(
        sender_name: @idgtl.sender_name,
        destination: phone,
        content: text,
        external_message_id: "idgtl-test-#{current_account.id}-#{Time.current.to_i}"
      )
      success = result[:ok]
      message = t("idgtls.test_sms.success", default: "Test SMS sent") if success
    else
      message = t("idgtls.test_sms.no_settings")
    end

    respond_to do |format|
      flash.now[success ? :success : :error] = message
      format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [render_turbo_flash] }
      format.html { redirect_to account_idgtls_path(current_account) }
    end
  rescue SmsProviders::IdgtlClient::ApiError => e
    respond_to do |format|
      flash.now[:error] = "i-dgtl error (#{e.http_status}): #{e.raw}"
      format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [render_turbo_flash] }
      format.html { redirect_to account_idgtls_path(current_account) }
    end
  rescue => e
    respond_to do |format|
      flash.now[:error] = e.message
      format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [render_turbo_flash] }
      format.html { redirect_to account_idgtls_path(current_account) }
    end
  end

  def info; end

  private

  def set_idgtl
    @idgtl = current_account.idgtl
  end

  def idgtl_params
    params.require(:idgtl).permit(:token_1, :sender_name)
  end
end

