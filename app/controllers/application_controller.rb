class ApplicationController < ActionController::Base
  include Authentication
  include OffcanvasResponder
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_locale
  before_action :load_session
  before_action :set_current_account, except: [:switch_locale]
  before_action :ensure_user_in_current_account, except: [:switch_locale]
  before_action :ensure_active_subscription, except: [:switch_locale]
  helper_method :current_account, :current_locale
  
  def switch_locale
    session[:locale] = params[:locale]
    redirect_back fallback_location: root_path
  end

  private

  # Hotwire helper to update the flash container via turbo_stream
  def render_turbo_flash
    turbo_stream.replace("flash", partial: "shared/flash")
  end

  def load_session
    # Ensure Current.session is available even on unauthenticated pages
    if Current.session.nil? && respond_to?(:find_session_by_cookie, true)
      Current.session = find_session_by_cookie
    end
  end

  def set_current_account
    Current.account =
    if params[:account_id].present?
      Account.find_by(id: params[:account_id])
    elsif Current.session&.user
      # Приоритет: первый аккаунт пользователя или админ-аккаунт
      Current.session.user.accounts.first || Account.where(admin: true).first
    end
  end

  def ensure_user_in_current_account
    return unless Current.session && Current.account

    user_accounts = Current.session.user&.accounts || []
    admin_account = user_accounts.find { |acc| acc.admin? }
    return if admin_account
    
    # Ensure the authenticated user belongs to the current account
    unless Current.user.accounts.include?(Current.account)
      terminate_session
      redirect_to new_session_path, alert: "Please sign in for this account."
    end
  end

  # Uniform admin check for account-scoped controllers
  def ensure_account_admin
    return unless Current.session && Current.account

    account_user = Current.session.user.account_users.find_by(account: Current.account)
    unless account_user&.admin?
      flash[:error] = t('access_denied')
      redirect_to account_dashboard_path(Current.account)
    end
  end

  # Проверяет наличие активной подписки для доступа к функциям приложения
  # Для веб-эндпоинтов: требует сессию (проверяется через require_authentication)
  # Для API-эндпоинтов: проверяет подписку без сессии (API пропускает аутентификацию)
  def ensure_active_subscription
    return unless Current.account
    
    # Разрешаем доступ админ-аккаунтам
    return if Current.account.admin?
    
    # Разрешаем доступ к страницам подписок и платежей
    return if controller_name.in?(%w[subscriptions payments]) || controller_path.start_with?('admin/')
    
    # Разрешаем выход из системы без проверки подписки
    return if controller_name == 'sessions' && action_name == 'destroy'
    
    # Для API-эндпоинтов проверяем подписку даже без сессии
    # (API-контроллеры пропускают require_authentication, но должны проверять подписку)
    if controller_path.start_with?('api/')
      unless Current.account.subscription_active?
        render json: { 
          error: 'Subscription required', 
          message: 'Active subscription required to access this API endpoint' 
        }, status: :payment_required
        return
      end
    else
      # Для веб-эндпоинтов требуем сессию (обычные пользователи должны быть аутентифицированы)
      # Сессия уже проверена через require_authentication, но проверяем еще раз для безопасности
      return unless Current.session
      
      # Проверяем активную подписку
      unless Current.account.subscription_active?
        flash[:alert] = t('subscriptions.access_restricted', default: 'Active subscription required. Please subscribe to continue.')
        redirect_to account_subscriptions_path(Current.account)
      end
    end
  end

  def current_account
    Current.account
  end
  
  def set_locale
    I18n.locale = session[:locale] || I18n.default_locale
  end
  
  def current_locale
    I18n.locale
  end
  
end
