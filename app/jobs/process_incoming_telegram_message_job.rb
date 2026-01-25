class ProcessIncomingTelegramMessageJob < ApplicationJob
  queue_as :default

  def perform(account_id:, message:)
    account = Account.find_by(id: account_id)
    return unless account

    Rails.logger.info "[ProcessIncomingTelegramMessageJob] Processing message for account ##{account_id}: #{message.inspect}"
    
    # Структура message от микросервиса может быть разной
    # Ожидаем: { "from_id": 123, "from_username": "username", "from_phone": "+7...", "text": "...", "message_id": 123, "date": "..." }
    from_id = message['from_id'] || message['from']['id'] rescue nil
    from_username = message['from_username'] || (message['from'] && message['from']['username']) rescue nil
    from_phone = message['from_phone'] || (message['from'] && message['from']['phone']) rescue nil
    text = message['text'] || message['message'] || ''
    message_id = message['message_id'] || message['id']
    chat_id = message['chat_id'] || (message['chat'] && message['chat']['id']) rescue nil
    
    return unless from_id || from_username || from_phone
    
    # Находим или создаем клиента
    client = find_or_create_client(
      account: account,
      telegram_user_id: from_id&.to_s,
      username: from_username,
      phone: from_phone,
      chat_id: chat_id&.to_s
    )
    
    return unless client
    
    return if client.telegram_block?

    # Используем активный диалог по клиенту или создаём новый (не подставляем закрытый)
    conversation = account.conversations.active.find_by(client: client) ||
                   account.conversations.create!(client: client, status: :active)
    
    # Создаем входящее сообщение
    message_record = conversation.messages.create!(
      account: account,
      client: client,
      direction: 'incoming',
      channel: 'telegram',
      content: text,
      message_id: message_id&.to_s,
      status: 'delivered',
      delivered_at: Time.current
    )
    
    # Обновляем timestamps conversation
    conversation.update_timestamps
    
    # Обновляем статус последнего исходящего сообщения (если есть ожидающее)
    last_outgoing = conversation.messages.outgoing.order(created_at: :desc).first
    if last_outgoing && last_outgoing.status == 'sent'
      last_outgoing.update(status: 'delivered', delivered_at: Time.current)
    end
    
    Rails.logger.info "[ProcessIncomingTelegramMessageJob] Saved incoming message ##{message_record.id} for client ##{client.id}"
    
    message_record
  rescue => e
    Rails.logger.error "[ProcessIncomingTelegramMessageJob] Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end
  
  private
  
  def find_or_create_client(account:, telegram_user_id: nil, username: nil, phone: nil, chat_id: nil)
    # Собираем все возможные критерии поиска
    search_criteria = []
    
    # Поиск по telegram_chat_id (приоритетный)
    if chat_id.present?
      client = account.clients.find_by(telegram_chat_id: chat_id)
      return update_client_telegram_data(client, chat_id: chat_id, telegram_user_id: telegram_user_id, username: username) if client
      search_criteria << { telegram_chat_id: chat_id }
    end
    
    # Поиск по telegram_user_id
    if telegram_user_id.present?
      client = account.clients.find_by(telegram_chat_id: telegram_user_id)
      return update_client_telegram_data(client, chat_id: chat_id, telegram_user_id: telegram_user_id, username: username) if client
      search_criteria << { telegram_chat_id: telegram_user_id }
    end
    
    # Поиск по username
    if username.present?
      normalized_username = username.start_with?('@') ? username : "@#{username}"
      client = account.clients.find_by(telegram_username: normalized_username)
      if client
        return update_client_telegram_data(client, chat_id: chat_id, telegram_user_id: telegram_user_id, username: username)
      end
    end
    
    # Пытаемся найти по телефону (с нормализацией: "+79777315711" и "79777315711" считаются одним номером)
    if phone.present?
      canonical = normalize_phone(phone)
      return nil unless canonical
      variants = [canonical, "+#{canonical}"].uniq
      client = account.clients.where(phone: variants).first
      unless client
        account.clients.find_each do |c|
          if c.phone.present? && normalize_phone(c.phone) == canonical
            client = c
            break
          end
        end
      end
      
      if client
        # Обновляем данные клиента
        client = update_client_telegram_data(client, chat_id: chat_id, telegram_user_id: telegram_user_id, username: username)
        # Обновляем телефон, если он в другом формате
        if client.phone.blank? || normalize_phone(client.phone) != canonical
          client.update_column(:phone, phone)
        end
        return client
      end
    end
    
    # Создаем нового клиента
    account.clients.create!(
      name: username || phone || "Telegram User",
      telegram_chat_id: chat_id || telegram_user_id,
      telegram_username: username.present? ? (username.start_with?('@') ? username : "@#{username}") : nil,
      phone: phone
    )
  end
  
  # Канонический вид: только цифры, 89xxxxxxxxx -> 79xxxxxxxxx. Чтобы "+79777315711" и "79777315711" совпадали.
  def normalize_phone(value)
    return nil unless value.present?
    digits = value.to_s.gsub(/\D/, "")
    digits.sub!(/\A8(\d{10})\z/, '7\1') if digits.size == 11
    digits.presence
  end
  
  def update_client_telegram_data(client, chat_id: nil, telegram_user_id: nil, username: nil)
    return client unless client
    
    updates = {}
    
    # Обновляем telegram_chat_id если его нет
    if client.telegram_chat_id.blank? && (chat_id.present? || telegram_user_id.present?)
      updates[:telegram_chat_id] = chat_id || telegram_user_id
    end
    
    # Обновляем username если его нет
    if username.present? && client.telegram_username.blank?
      updates[:telegram_username] = username.start_with?('@') ? username : "@#{username}"
    end
    
    client.update_columns(updates) if updates.any?
    client
  end
end
