class MoizvonkisController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_moizvonki, only: %i[show edit update destroy test_sms_form test_sms]

  def index
    @moizvonki = current_account.moizvonki
  end

  def show; end

  def new
    if current_account.moizvonki.present?
      respond_to do |format|
        notice = t(".already_exists")
        flash.now[:notice] = notice
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash }
        format.html { redirect_to account_moizvonkis_path(current_account), notice: notice }
      end
    else
      @moizvonki = current_account.build_moizvonki
    end
  end

  def edit; end

  def create
    @moizvonki = current_account.build_moizvonki(moizvonki_params)

    respond_to do |format|
      if @moizvonki.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.update(
              :moizvonkis_actions,
              partial: "moizvonkis/actions",
              locals: { moizvonki: @moizvonki }
            ),
            turbo_stream.update(
              "moizvonkis",
              partial: "moizvonkis/index_content",
              locals: { moizvonki: @moizvonki, current_account: current_account }
            )
          ]
        end
        format.html { redirect_to account_moizvonkis_path(current_account), notice: t(".success") }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @moizvonki.update(moizvonki_params)
        message = t(".success")
        flash.now[:success] = message
        format.turbo_stream do
          render turbo_stream: [
            render_turbo_flash,
            turbo_stream.update(:offcanvas, ""),
            turbo_stream.update(
              :moizvonkis_actions,
              partial: "moizvonkis/actions",
              locals: { moizvonki: @moizvonki }
            ),
            turbo_stream.update(
              "moizvonkis",
              partial: "moizvonkis/index_content",
              locals: { moizvonki: @moizvonki, current_account: current_account }
            )
          ]
        end
        format.html { redirect_to account_moizvonkis_path(current_account), notice: message }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @moizvonki.destroy!

    respond_to do |format|
      message = t(".success")
      flash.now[:success] = message
      format.turbo_stream do
        render turbo_stream: turbo_close_offcanvas_flash + [
          turbo_stream.update(:moizvonkis_actions, partial: "moizvonkis/actions"),
          turbo_stream.update(
            "moizvonkis",
            partial: "moizvonkis/index_content",
            locals: { moizvonki: nil, current_account: current_account }
          )
        ]
      end
      format.html { redirect_to account_moizvonkis_path(current_account), notice: message }
    end
  end

  def test_sms_form; end

  def test_sms
    phone = params[:test_phone].to_s
    text = params[:test_text].presence || "Test SMS from Moizvonki settings for account ##{current_account.id}"

    success = false
    message = t("moizvonkis.test_sms.error")

    if @moizvonki.present?
      client = SmsProviders::MoizvonkiClient.new(
        domain: @moizvonki.domain,
        user_name: @moizvonki.user_name,
        api_key: @moizvonki.api_key
      )
      client.send_sms!(to: phone, text: text)
      success = true
      message = t("moizvonkis.test_sms.success")
    else
      message = t("moizvonkis.test_sms.no_settings")
    end

    respond_to do |format|
      flash.now[success ? :success : :error] = message
      format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [render_turbo_flash] }
      format.html { redirect_to account_moizvonkis_path(current_account) }
    end
  rescue SmsProviders::MoizvonkiClient::ApiError => e
    respond_to do |format|
      flash.now[:error] = "Moizvonki error (#{e.http_status}): #{e.raw}"
      format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [render_turbo_flash] }
      format.html { redirect_to account_moizvonkis_path(current_account) }
    end
  rescue => e
    respond_to do |format|
      flash.now[:error] = e.message
      format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [render_turbo_flash] }
      format.html { redirect_to account_moizvonkis_path(current_account) }
    end
  end

  def info; end

  private

  def set_moizvonki
    @moizvonki = current_account.moizvonki
  end

  def moizvonki_params
    params.require(:moizvonki).permit(:domain, :user_name, :api_key)
  end
end

