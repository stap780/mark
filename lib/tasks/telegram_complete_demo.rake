namespace :telegram do
  desc "Authorize MTProto for account and save session (send_code + sign_in)"
  desc "⚠️ DEPRECATED: This task uses old telegram-mtproto-ruby. Use microservice instead."
  task complete_demo: :environment do
    # ВНИМАНИЕ: Эта задача использует старый способ авторизации через telegram-mtproto-ruby.
    # В продакшене используется Python микросервис (Telethon).
    # Эта задача оставлена только для тестирования/отладки старого способа.
    begin
      require "telegram_mtproto"
    rescue LoadError
      puts "❌ Гем telegram-mtproto-ruby не установлен."
      puts "   Эта задача использует устаревший способ авторизации."
      puts "   В продакшене используется Python микросервис."
      puts "   Для установки гема вручную: gem install telegram-mtproto-ruby"
      exit 1
    end

    puts "\n🚀 MTProto authorize & save session (telegram:complete_demo)"
    puts "-" * 80

    # --- Аккаунт, в который сохраняем сессию ---
    account_id = (ENV["ACCOUNT_ID"] || 2).to_i
    account = Account.find_by(id: account_id)

    unless account
      puts "❌ Account ##{account_id} not found"
      exit 1
    end

    telegram_setup = account.telegram_setup || account.build_telegram_setup

    # --- Креды и номер ---
    api_id  = 31670543 #Rails.application.credentials.dig(:telegram, :api_id)
    api_hash = "e36bc3106f9f843d95a2c33ea9e8b03c" #Rails.application.credentials.dig(:telegram, :api_hash)

    if api_id.blank? || api_hash.blank?
      puts "❌ В credentials нет telegram.api_id / telegram.api_hash"
      puts "Добавь в credentials:"
      puts "telegram:"
      puts "  api_id: 31670543"
      puts '  api_hash: "e36bc3106f9f843d95a2c33ea9e8b03c"'
      exit 1
    end

    phone = ENV["PHONE"] || telegram_setup.personal_phone

    if phone.blank?
      puts "❌ PHONE не задан и в telegram_setup.personal_phone тоже пусто"
      puts "   Запусти так: PHONE=+7901... ACCOUNT_ID=#{account_id} bundle exec rake telegram:complete_demo"
      exit 1
    end

    puts "📱 Phone: #{phone}"
    puts "🔑 API ID: #{api_id}"
    puts "🆔 API Hash: #{api_hash.to_s[0..10]}..."
    puts "-" * 80

    client = TelegramMtproto.new(api_id, api_hash, phone)

    # --- Шаг 1: auth.sendCode ---
    puts "\n📤 Step 1: Sending auth code (auth.sendCode)..."
    send_result = client.send_code

    unless send_result[:success]
      puts "❌ Failed to send code: #{send_result[:error]}"
      exit 1
    end

    phone_code_hash = send_result[:phone_code_hash]
    puts "✅ Code sent successfully"
    puts "📱 Code type: #{send_result[:code_type]}" if send_result[:code_type].present?
    puts "📄 phone_code_hash: #{phone_code_hash.inspect}"

    # --- Ввод PIN ---
    puts "\nВведите код, который пришёл в Telegram на номер #{phone}:"
    print "🔢 PIN: "
    pin_code = STDIN.gets.to_s.strip

    # --- Шаг 2: auth.signIn ---
    puts "\n🔐 Step 2: Signing in (auth.signIn)..."
    auth_result = client.sign_in(phone_code_hash, pin_code)

    puts "\n📦 Raw auth_result:"
    pp auth_result

    unless auth_result[:success]
      puts "❌ Authentication failed: #{auth_result[:error]}"
      exit 1
    end

    puts "✅ Successfully authenticated via MTProto!"

    # --- Сохранение MTProto‑сессии в аккаунте ---
    if client.respond_to?(:dump_session)
      session_data = client.dump_session

      telegram_setup.personal_phone      = phone
      telegram_setup.personal_session    = session_data
      telegram_setup.personal_authorized = true
      telegram_setup.save!

      puts "\n💾 Session saved for Account ##{account_id}"
      puts "   personal_authorized: true"
      puts "   personal_phone: #{phone}"
      puts "   personal_session length: #{session_data.to_s.bytesize} bytes"

      # Примечание: TelegramPersonalListenerJob больше не используется.
      # Входящие сообщения теперь обрабатываются через Python микросервис (webhooks).
    else
      puts "⚠️ client.dump_session недоступен, сессию сохранить нельзя"
    end

    puts "\n===" * 20
    puts "Теперь можно открыть настройки Telegram для аккаунта:"
    puts "  http://localhost:3000/accounts/#{account_id}/telegram_setups"
    puts "и отправить тестовое сообщение от личного аккаунта."
    puts "Команда для запуска ещё раз:"
    puts "  PHONE=#{phone} ACCOUNT_ID=#{account_id} bundle exec rake telegram:complete_demo"
    puts "===" * 20
  end
end

