class Insnotify < ApplicationRecord
  belongs_to :user

  validates :uid, presence: true, uniqueness: true
  validates :user_id, presence: true

  scope :installed, -> { where(installed: true) }
  
  def installed?
    installed == true
  end

  # Создаёт или обновляет установку Insnotify для пользователя
  # Порядок создания как в seeds.rb: сначала Account, потом User, потом связи
  def self.install_or_update(uid:, email:, shop:, insales_app_identifier: nil, insales_api_password: nil)
    # 1. Создаём или находим аккаунт
    account = Account.find_or_create_by!(name: "Insnotify #{uid} Account") do |acc|
      acc.partner = true
      logo = "https://insales-static.obs.ru-moscow-1.hc.sbercloud.ru/images/applications/4141349/1762959273-ChatGPT_Image_Nov_10__2025__07_14_15_PM.normal.png"
      acc.settings = { apps: ['insnotify'], logo: logo }
    end
    
    # 2. Создаём или находим пользователя
    user = User.find_or_initialize_by(email_address: email)
    if user.new_record?
      password = SecureRandom.base58(24)
      user.assign_attributes(
        password: password,
        password_confirmation: password
      )
      user.save!
    end
    
    # 3. Создаём или обновляем связь пользователя с аккаунтом (порядок как в seeds.rb)
    account_user = account.account_users.find_or_initialize_by(user: user)
    account_user.role = 'member'
    account_user.save!

    # 4. Создаём или обновляем связь с Insnotify
    insnotify = user.insnotify || user.build_insnotify
    insnotify.update!(
      uid: uid,
      shop: shop,
      installed: true
    )

    # 5. Создаём или обновляем запись InSales, если переданы данные
    if insales_app_identifier.present? && insales_api_password.present? && shop.present?
      begin
        # Форматируем api_link: если shop не содержит протокол, добавляем https://
        api_link = shop.start_with?('http') ? shop : "https://#{shop}"
        Rails.logger.info "Creating InSales record for account #{account.id}, api_key: #{insales_app_identifier[0..10]}..., api_link: #{api_link}"
        
        # Устанавливаем контекст аккаунта для AccountScoped
        Account.switch_to(account.id)
        # Используем связь account.insales (у аккаунта может быть только один Insale)
        insale = account.insales.first_or_initialize
        
        # Проверяем валидность перед сохранением
        insale.api_key = insales_app_identifier
        insale.api_password = insales_api_password
        insale.api_link = api_link
        
        unless insale.valid?
          Rails.logger.error "InSales validation errors: #{insale.errors.full_messages.join(', ')}"
          raise ActiveRecord::RecordInvalid.new(insale)
        end
        
        insale.save!
        Rails.logger.info "InSales record created/updated for account #{account.id}, id: #{insale.id}"
        
        # Создаём XML feed для InSales после успешного сохранения
        begin
          result, message = Insale.create_xml(account: account)
          if result
            Rails.logger.info "InSales XML feed created for account #{account.id}: #{message}"
          else
            Rails.logger.warn "Failed to create InSales XML feed for account #{account.id}: #{Array(message).join(', ')}"
          end
        rescue => e
          # Логируем ошибку, но не прерываем установку
          Rails.logger.error "Error creating InSales XML feed: #{e.class}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      rescue => e
        # Логируем ошибку, но не прерываем установку
        Rails.logger.error "Failed to create InSales record: #{e.class}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    else
      Rails.logger.warn "InSales data missing: app_identifier=#{insales_app_identifier.present?}, api_password=#{insales_api_password.present?}, shop=#{shop.present?}"
    end

    # 6. Создаём форму notify и правило автоматизации
    create_notify_setup(account)
    
    [insnotify, account]
  end

  # Находит или создаёт пользователя для автологина и обновляет last_login_at
  # Возвращает [user, account] или nil если пользователь не найден и не может быть создан
  def self.autologin_user(uid:, email:, shop:)
    # Ищем пользователя по email
    user = User.find_by(email_address: email)
    
    # Если пользователя нет, создаём его через install_or_update
    if user.nil?
      insnotify, account = install_or_update(uid: uid, email: email, shop: shop)
      user = insnotify.user
    else
      # Ищем аккаунт с insnotify в настройках
      account = user.accounts.find { |acc| acc.settings.dig("apps")&.include?('insnotify') }
      
      # Если аккаунт не найден, создаём через install_or_update
      if account.nil?
        insnotify, account = install_or_update(uid: uid, email: email, shop: shop)
      else
        # Обновляем связь с Insnotify (обновляем last_login_at)
        insnotify = user.insnotify || user.create_insnotify(uid: uid, shop: shop)
        insnotify.update!(
          uid: uid,
          shop: shop,
          last_login_at: Time.current
        )
      end
    end
    
    [user, account]
  end

  # Создаёт форму notify и правило автоматизации для аккаунта
  def self.create_notify_setup(account)
    Account.switch_to(account.id)
    
    # 1. Создаем форму notify
    webform = account.webforms.find_or_create_by(kind: 'notify') do |wf|
      wf.title = "Сообщить о поступлении"
      wf.status = "active"
      wf.trigger_type = 'event'
      wf.show_delay = 0
      wf.show_once_per_session = true
      wf.target_devices = "desktop,mobile,tablet"
      wf.show_times = 0
    end
    
    # 2. Создаем шаблон сообщения
    template = account.message_templates.find_or_create_by(
      title: "Товар появился в наличии",
      channel: "email"
    ) do |t|
      t.subject = 'Товары появились в наличии!'
      t.content = '<!DOCTYPE html>
<html>
  <body style="font-family: system-ui, -apple-system, BlinkMacSystemFont, \'Segoe UI\', sans-serif; font-size: 14px; color: #111827; margin: 0; padding: 0;">
    <div style="max-width: 600px; margin: 0 auto; padding: 24px; background-color: #ffffff;">
      <h1 style="font-size: 20px; margin: 0 0 16px; color: #111827;">Товары появились в наличии</h1>

      <p style="margin: 0 0 12px;">Здравствуйте, {{ client.name }}!</p>
      <p style="margin: 0 0 16px;">Товары, на которые вы подписались, появились в наличии:</p>

      <table style="width: 100%; border-collapse: collapse; margin-bottom: 16px;">
        <thead>
          <tr>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;">Товар</th>
            <th align="left" style="padding: 8px; border-bottom: 1px solid #e5e7eb; font-size: 12px; color: #6b7280;"></th>
          </tr>
        </thead>
        <tbody>
          {% for incase in client.incases_for_notify %}
            {% for item in incase.items %}
              <tr>
                <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;">{{ item.product_title }}</td>
                <td style="padding: 8px; border-bottom: 1px solid #f3f4f6; font-size: 13px; color: #111827;"><a href="{{ item.product_link }}" style="color: #2563eb; text-decoration: none;">подробнее</a></td>
              </tr>
            {% endfor %}
          {% endfor %}
        </tbody>
      </table>

      <p style="margin: 16px 0 0; font-size: 12px; color: #9ca3af;">С уважением,<br/>команда магазина.</p>
    </div>
  </body>
</html>'
    end
    
    # 3. Создаем правило автоматизации
    rule = account.automation_rules.find_or_create_by(
      event: 'variant.back_in_stock',
      title: "Уведомление о поступлении товара"
    ) do |r|
      r.condition_type = "simple"
      r.active = false # По умолчанию неактивно
      r.delay_seconds = 0
      r.logic_operator = "AND"
    end
    
    # 4. Создаем условия правила
    rule.automation_conditions.find_or_create_by(
      field: "incase.webform.kind",
      operator: "equals",
      value: "notify",
      position: 1
    )
    
    rule.automation_conditions.find_or_create_by(
      field: "variant.quantity",
      operator: "greater_than",
      value: "0",
      position: 2
    )
    
    # 5. Создаем действия правила
    rule.automation_actions.find_or_create_by(
      kind: "send_email",
      position: 1
    ) do |a|
      a.value = template.id.to_s
    end
    
    rule.automation_actions.find_or_create_by(
      kind: "change_status",
      position: 2
    ) do |a|
      a.value = "done"
    end
    
    # Сохраняем правило для обновления condition_json
    rule.save!
    
    [webform, rule]
  end
  
end

