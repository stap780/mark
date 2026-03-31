# Выполняет Automation::Engine для событий заявки в фоне (после ответа HTTP).
# Раньше Engine вызывался синхронно из after_create_commit / after_update_commit и удлинял API (в т.ч. веб-формы).
class AutomationIncaseEventJob < ApplicationJob
  queue_as :automation_incase_events

  discard_on ActiveRecord::RecordNotFound

  def perform(account_id:, incase_id:, event:)
    account = Account.find(account_id)
    incase = account.incases.find(incase_id)

    Automation::Engine.call(account: account, event: event, object: incase)
  end
end
