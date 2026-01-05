class Inswatch < ApplicationRecord
  belongs_to :user

  validates :uid, presence: true, uniqueness: true
  validates :user_id, presence: true

  scope :installed, -> { where(installed: true) }
  
  def installed?
    installed == true
  end

  # Создаёт или обновляет установку Inswatch для пользователя
  # Порядок создания как в seeds.rb: сначала Account, потом User, потом связи
  def self.install_or_update(uid:, email:, shop:, insales_app_identifier: nil, insales_api_password: nil)
    # 1. Создаём или находим аккаунт
    account = Account.find_or_create_by!(name: "Inswatch #{uid} Account") do |acc|
      acc.partner = true
      logo = "https://insales-static.obs.ru-moscow-1.hc.sbercloud.ru/images/applications/4141349/1762959273-ChatGPT_Image_Nov_10__2025__07_14_15_PM.normal.png"
      acc.settings = { apps: ['inswatch'], logo: logo }
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

    # 4. Создаём или обновляем связь с Inswatch
    inswatch = user.inswatch || user.build_inswatch
    inswatch.update!(
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
    
    [inswatch, account]
  end

  # Находит или создаёт пользователя для автологина и обновляет last_login_at
  # Возвращает [user, account] или nil если пользователь не найден и не может быть создан
  def self.autologin_user(uid:, email:, shop:)
    # Ищем пользователя по email
    user = User.find_by(email_address: email)
    
    # Если пользователя нет, создаём его через install_or_update
    if user.nil?
      inswatch, account = install_or_update(uid: uid, email: email, shop: shop)
      user = inswatch.user
    else
      # Ищем аккаунт с inswatch в настройках
      account = user.accounts.find { |acc| acc.settings.dig("apps")&.include?('inswatch') }
      
      # Если аккаунт не найден, создаём через install_or_update
      if account.nil?
        inswatch, account = install_or_update(uid: uid, email: email, shop: shop)
      else
        # Обновляем связь с Inswatch (обновляем last_login_at)
        inswatch = user.inswatch || user.create_inswatch(uid: uid, shop: shop)
        inswatch.update!(
          uid: uid,
          shop: shop,
          last_login_at: Time.current
        )
      end
    end
    
    [user, account]
  end
  
end

