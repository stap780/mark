class InswatchController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:install, :autologin]
  skip_before_action :set_current_account, only: [:install, :autologin]
  skip_before_action :ensure_user_in_current_account, only: [:install, :autologin]
  skip_before_action :ensure_active_subscription, only: [:install, :autologin]
  allow_unauthenticated_access only: [:install, :autologin]

  # GET /inswatch/install
  # Установка приложения: создание/связывание пользователя в Mark
  def install
    uid = params[:uid]
    email = params[:email]
    timestamp = params[:timestamp].to_i
    signature = params[:signature]
    shop = params[:shop]

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

    # Ищем пользователя по email
    user = User.find_by(email_address: email)
    
    # Если пользователя нет, создаём его
    if user.nil?
      user = create_user_from_inswatch(email, uid, shop)
    end

    if user
      # Создаём или обновляем связь с Inswatch
      inswatch = user.inswatch || user.build_inswatch
      inswatch.update!(
        uid: uid,
        shop: shop,
        installed: true
      )
      
      # Создаём аккаунт, если его нет
      ensure_account_exists(user)
      
      head :ok
    else
      head :unprocessable_entity
    end
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

    # Ищем пользователя по email
    user = User.find_by(email_address: email)
    
    # Если пользователя нет, создаём его
    if user.nil?
      user = create_user_from_inswatch(email, uid, shop)
    end

    unless user
      redirect_to new_session_path, alert: "Пользователь не найден"
      return
    end

    # Обновляем связь с Inswatch (обновляем last_login_at)
    inswatch = user.inswatch || user.create_inswatch(
      uid: uid,
      shop: shop
    )
    inswatch.update!(last_login_at: Time.current)

    # Убеждаемся, что у пользователя есть аккаунт
    ensure_account_exists(user)

    # Создаём сессию
    start_new_session_for(user)

    # Определяем аккаунт для пользователя
    account = determine_account_for_user(user)
    
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

  # Создаёт пользователя в Mark на основе данных из Inswatch
  def create_user_from_inswatch(email, uid, shop)
    password = SecureRandom.base58(24)
    user = User.create!(
      email_address: email,
      password: password,
      password_confirmation: password
    )
    
    # Создаём связь с Inswatch
    user.create_inswatch!(
      uid: uid,
      shop: shop
    )
    
    # Создаём первый аккаунт для пользователя с названием на основе uid
    # Устанавливаем флаг partner = true и settings.apps для аккаунтов из Inswatch
    account = user.accounts.create!(
      name: "Inswatch #{uid} Account",
      partner: true,
      settings: { apps: ['inswatch'] }
    )
    user.account_users.create!(account: account, role: 'admin')
    
    user
  end

  # Убеждаемся, что у пользователя есть аккаунт
  def ensure_account_exists(user)
    return if user.accounts.any?
    
    # Получаем uid из связи с Inswatch
    uid = user.inswatch&.uid || user.id.to_s
    # Устанавливаем флаг partner = true и settings.apps для аккаунтов из Inswatch
    account = user.accounts.create!(
      name: "Inswatch #{uid} Account",
      partner: true,
      settings: { apps: ['inswatch'] }
    )
    user.account_users.create!(account: account, role: 'admin')
  end

  # Определяет аккаунт для пользователя
  def determine_account_for_user(user)
    # Вариант 1: Использовать первый аккаунт
    account = user.accounts.first
    
    # Вариант 2: Если передан account_id в токене (если добавим в payload)
    # account_id = data['account_id']
    # account = user.accounts.find_by(id: account_id) if account_id
    
    # Вариант 3: Создать аккаунт, если его нет
    if account.nil?
      # Получаем uid из связи с Inswatch
      uid = user.inswatch&.uid || user.id.to_s
      # Устанавливаем флаг partner = true и settings.apps для аккаунтов из Inswatch
      account = user.accounts.create!(
        name: "Inswatch #{uid} Account",
        partner: true,
        settings: { apps: ['inswatch'] }
      )
      user.account_users.create!(account: account, role: 'admin')
    end
    
    account
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

