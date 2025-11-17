class InswatchController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:install, :autologin]
  skip_before_action :set_current_account, only: [:install, :autologin]
  skip_before_action :ensure_user_in_current_account, only: [:install, :autologin]
  skip_before_action :ensure_active_subscription, only: [:install, :autologin]
  allow_unauthenticated_access only: [:install, :autologin]

  # Установка приложения: создание/связывание пользователя в Mark
  def install
    uid = params[:uid]
    email = params[:email]
    timestamp = params[:timestamp].to_i
    signature = params[:signature]
    shop = params[:shop]
    insales_secret_key = params[:insales_secret_key]
    insales_api_password = params[:insales_api_password]
    insales_app_identifier = params[:insales_app_identifier]

    # Проверяем подпись
    unless valid_signature?(uid, email, timestamp, signature)
      head :unauthorized
      return
    end

    # Проверяем expiration (5 минут)
    if Time.now.to_i - timestamp > 5.minutes.to_i
      head :unauthorized
      return
    end

    # Создаём или обновляем установку через модель (порядок как в seeds.rb)
    # Включая создание InSales записи, если переданы данные
    Inswatch.install_or_update(
      uid: uid,
      email: email,
      shop: shop,
      insales_app_identifier: insales_app_identifier,
      insales_api_password: insales_api_password
    )
    
    head :ok
  rescue => e
    Rails.logger.error "Install error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    head :internal_server_error
  end

  # GET /inswatch/autologin
  # Автологин пользователя из Inswatch
  def autologin
    uid = params[:uid]
    email = params[:email]
    timestamp = params[:timestamp].to_i
    signature = params[:signature]
    shop = params[:shop]
    return_to = params[:return_to]

    # Проверяем подпись
    unless valid_signature?(uid, email, timestamp, signature)
      redirect_to new_session_path, alert: "Неверная подпись"
      return
    end

    # Проверяем expiration (5 минут)
    if Time.now.to_i - timestamp > 5.minutes.to_i
      redirect_to new_session_path, alert: "Ссылка истекла. Пожалуйста, войдите снова."
      return
    end

    # Находим или создаём пользователя через модель
    result = Inswatch.autologin_user(uid: uid, email: email, shop: shop)
    
    unless result
      redirect_to new_session_path, alert: "Пользователь не найден"
      return
    end
    
    user, account = result
    
    unless account
      redirect_to new_session_path, alert: "Аккаунт не найден. Пожалуйста, выполните установку приложения."
      return
    end

    # Создаём сессию
    start_new_session_for(user)
    
    # Редиректим на нужную страницу
    redirect_to after_authentication_url(account, return_to)
  rescue => e
    Rails.logger.error "Auto-login error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    redirect_to new_session_path, alert: "Ошибка автологина"
  end

  private

  SECRET = Rails.application.credentials.inswatch[:app_secret]

  # Проверяет подпись запроса (MD5, как в InSales)
  def valid_signature?(uid, email, timestamp, signature)
    message = "#{uid}:#{email}:#{timestamp}"
    expected_signature = Digest::MD5.hexdigest(message + SECRET)
    ActiveSupport::SecurityUtils.secure_compare(signature.to_s, expected_signature)
  end

  # URL для редиректа после автологина
  def after_authentication_url(account, return_to = nil)
    if return_to.present?
      # Проверяем, что return_to — это наш домен (безопасность)
      begin
        uri = URI.parse(return_to)
        if uri.host == request.host || uri.host.nil?
          return return_to
        end
      rescue URI::InvalidURIError
        # Если невалидный URL, игнорируем
      end
    end
    
    # По умолчанию редиректим на dashboard аккаунта
    account_dashboard_path(account)
  end
  
end