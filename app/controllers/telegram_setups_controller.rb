
class TelegramSetupsController < ApplicationController
  before_action :set_telegram_setup, only: %i[show edit update destroy authorize_personal verify_code test_message_form test_message]
  include ActionView::RecordIdentifier

  def index
    @telegram_setup = current_account.telegram_setup
  end

  def show; end

  def new
    if current_account.telegram_setup.present?
      respond_to do |format|
        notice = t('.already_exists')
        flash.now[:notice] = notice
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash }
        format.html { redirect_to account_telegram_setups_path(current_account), notice: notice }
      end
    else
      @telegram_setup = current_account.build_telegram_setup
    end
  end

  def edit; end

  def create
    @telegram_setup = current_account.build_telegram_setup(telegram_setup_params)

    respond_to do |format|
      if @telegram_setup.save
        # Webhook устанавливается автоматически через after_save callback
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(current_account, "actions"),
              partial: "telegram_setups/actions",
              locals: { telegram_setup: @telegram_setup }
            ),
            turbo_stream.append(
              dom_id(current_account, "telegram_setups"),
              partial: "telegram_setups/telegram_setup",
              locals: { telegram_setup: @telegram_setup, current_account: current_account }
            )
          ]
        end
        format.html { redirect_to account_telegram_setups_path(current_account), notice: t('.success') }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @telegram_setup.update(telegram_setup_params)
        # Webhook устанавливается автоматически через after_save callback при изменении bot_token
        message = t('.success')
        flash.now[:success] = message
        format.turbo_stream do
          render turbo_stream: [
            render_turbo_flash,
            turbo_stream.update(:offcanvas, ""),
            turbo_stream.update(
              dom_id(current_account, "telegram_setups"),
              partial: "telegram_setups/index_content",
              locals: { telegram_setup: @telegram_setup, current_account: current_account }
            )
          ]
        end
        format.html { redirect_to account_telegram_setups_path(current_account), notice: message }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @telegram_setup.destroy!

    respond_to do |format|
      message = t('.success')
      flash.now[:success] = message
      format.turbo_stream do
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.replace(dom_id(current_account, "actions"), partial: "telegram_setups/actions", locals: { telegram_setup: nil }),
          turbo_stream.remove(dom_id(current_account, dom_id(@telegram_setup)))
        ]
      end
      format.html { redirect_to account_telegram_setups_path(current_account), notice: message }
    end
  end

  def authorize_personal
    # Если передан параметр reset, показываем форму заново
    if params[:reset] == 'true'
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            :offcanvas,
            template: "telegram_setups/authorize_personal",
            locals: { telegram_setup: @telegram_setup, current_account: current_account, phone: nil, phone_code_hash: nil }
          )
        end
        format.html { redirect_to authorize_personal_account_telegram_setup_path(current_account, @telegram_setup) }
      end
      return
    end
    
    # Форма для ввода номера телефона
    # Если номер уже введен, отправляем код
    if params[:phone].present?
      phone = params[:phone]

      # Используем микросервис вместо PersonalClient
      microservice = TelegramProviders::MicroserviceClient.new(account: current_account)
      result = microservice.send_code(phone: phone)

      if result[:ok]
        # Получаем phone_code_hash (это обычная строка, не требует кодирования)
        phone_code_hash = result[:data]['phone_code_hash']
        
        # Рендерим форму с кодом, передавая данные через локальные переменные
        respond_to do |format|
          flash.now[:success] = t('.code_sent')
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              :offcanvas,
              template: "telegram_setups/authorize_personal",
              locals: { 
                telegram_setup: @telegram_setup, 
                current_account: current_account,
                phone: phone,
                phone_code_hash: phone_code_hash
              }
            )
          end
          format.html { redirect_to account_telegram_setups_path(current_account) }
        end
      else
        respond_to do |format|
          flash.now[:error] = result[:error] || t('.send_code_error')
          format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [render_turbo_flash] }
          format.html { redirect_to account_telegram_setups_path(current_account) }
        end
      end
    else
      # Показываем начальную форму (ввод телефона)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            :offcanvas,
            template: "telegram_setups/authorize_personal",
            locals: { 
              telegram_setup: @telegram_setup, 
              current_account: current_account,
              phone: nil,
              phone_code_hash: nil
            }
          )
        end
        format.html { }
      end
    end
  end

  def verify_code
    phone = params[:phone]
    code = params[:code]
    password = params[:password] # Для двухфакторной аутентификации
    phone_code_hash = params[:phone_code_hash]

    unless phone_code_hash.present? && phone.present?
      respond_to do |format|
        flash.now[:error] = t('telegram_setups.authorize_personal.phone_code_hash_missing')
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [render_turbo_flash] }
        format.html { redirect_to account_telegram_setups_path(current_account) }
      end
      return
    end

    # Используем микросервис вместо PersonalClient
    microservice = TelegramProviders::MicroserviceClient.new(account: current_account)
    result = microservice.verify_code(
      phone: phone,
      code: code,
      phone_code_hash: phone_code_hash,
      password: password
    )
    Rails.logger.info "Telegram verify_code microservice result: #{result.inspect}"

    if result[:ok]
      # Сессия уже сохранена в PostgreSQL микросервисом
      @telegram_setup.update!(
        personal_phone: phone,
        personal_authorized: true
      )

      # Примечание: TelegramPersonalListenerJob больше не нужен,
      # так как микросервис сам обрабатывает входящие сообщения через webhooks
      success = true
      message = t('.success')
    else
      success = false
      message = result[:error] || t('.error')
    end

    respond_to do |format|
      flash.now[success ? :success : :error] = message
      
      if success
        # При успешной авторизации закрываем offcanvas и обновляем список
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            render_turbo_flash,
            turbo_stream.update(
              dom_id(current_account, "telegram_setups"),
              partial: "telegram_setups/index_content",
              locals: { telegram_setup: @telegram_setup.reload, current_account: current_account }
            ),
            turbo_stream.update(
              :telegram_setups_actions,
              partial: "telegram_setups/actions",
              locals: { telegram_setup: @telegram_setup }
            )
          ]
        end
      else
        # При ошибке обновляем форму
        format.turbo_stream do
          render turbo_stream: [
            render_turbo_flash,
            turbo_stream.update(
              :offcanvas,
              template: "telegram_setups/authorize_personal",
              locals: { telegram_setup: @telegram_setup, current_account: current_account }
            )
          ]
        end
      end
      
      format.html { redirect_to account_telegram_setups_path(current_account) }
    end
  end

  def test_message_form
    # Форма для тестового сообщения
  end

  def test_message
    recipient = params[:test_recipient] # telegram_chat_id или username
    text = params[:test_text].presence || "Test message from Telegram settings for account ##{current_account.id}"

    success = false
    message = t("telegram_setups.test_message.error")

    if @telegram_setup.present?
      # Создаем временного клиента для теста
      test_client = current_account.clients.build(
        telegram_chat_id: recipient.start_with?('@') ? nil : recipient,
        telegram_username: recipient.start_with?('@') ? recipient : nil,
        phone: recipient.start_with?('@') ? nil : recipient,
        name: "Test Client"
      )

      sender = TelegramProviders::MessageSender.new(account: current_account)
      result = sender.send(client: test_client, text: text)

      success = result[:ok]
      message = success ? t("telegram_setups.test_message.success") : (result[:error] || t("telegram_setups.test_message.error"))
    else
      message = t("telegram_setups.test_message.no_settings")
    end

    respond_to do |format|
      flash.now[success ? :success : :error] = message
      format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [render_turbo_flash] }
      format.html { redirect_to account_telegram_setups_path(current_account) }
    end
  rescue => e
    respond_to do |format|
      flash.now[:error] = e.message
      format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash + [render_turbo_flash] }
      format.html { redirect_to account_telegram_setups_path(current_account) }
    end
  end

  private

  def set_telegram_setup
    @telegram_setup = current_account.telegram_setup
  end

  def telegram_setup_params
    params.require(:telegram_setup).permit(:bot_token)
  end
end
