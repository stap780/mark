class IncaseNotifyGroupByClient
  def initialize(account)
    @account = account
  end

  def call
    # Ищем все заявки со статусом in_progress и типом notify
    incases = @account.incases
                     .includes(:client, :webform, items: { variant: :product })
                     .joins(:webform)
                     .where(status: 'in_progress')
                     .where(webforms: { kind: 'notify' })

    return [false, "No incases to process"] if incases.empty?

    # Находим правило автоматизации для события variant.back_in_stock
    rule = @account.automation_rules.active
                   .for_event('variant.back_in_stock')
                   .first

    return [false, "No automation rule found for 'variant.back_in_stock'"] unless rule

    action = rule.automation_actions.find_by(kind: 'send_email')
    return [false, "No 'send_email' action found in rule ##{rule.id}"] unless action

    # Группируем по клиенту и отправляем письма
    emails_sent = 0
    errors = []

    incases.group_by(&:client_id).each do |client_id, client_incases|
      client = client_incases.first.client
      next unless client&.email.present?

      # Собираем все варианты из заявок клиента
      client_variants = client_incases.flat_map do |incase|
        incase.items.map(&:variant)
      end.uniq

      next if client_variants.empty?

      primary_incase = client_incases.first
      webform = primary_incase.webform

      # Формируем контекст
      # incases доступны через client.incases_for_notify в Liquid шаблоне
      # Передаем все заявки клиента в ClientDrop
      context = {
        'client' => client,
        'incases' => client_incases, # Все заявки клиента для передачи в ClientDrop
        'variants' => client_variants,
        'webform' => webform
      }

      begin
        Automation::ActionExecutor.new(action, context, @account).call

        # Обновляем статус заявок на "done" после успешной отправки
        client_incases.each { |incase| incase.update_column(:status, 'done') }

        emails_sent += 1
        Rails.logger.info("IncaseNotifyGroupByClient: Sent email to client ##{client_id} with #{client_incases.count} incases")
      rescue => e
        error_msg = "Failed to send email to client ##{client_id}: #{e.message}"
        errors << error_msg
        Rails.logger.error("IncaseNotifyGroupByClient: #{error_msg}")
      end
    end

    result = {
      emails_sent: emails_sent,
      incases_updated: incases.count,
      errors: errors
    }

    [true, result]
  end
end

