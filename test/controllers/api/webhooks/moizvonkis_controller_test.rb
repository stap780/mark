require "test_helper"

class Api::Webhooks::MoizvonkisControllerTest < ActionDispatch::IntegrationTest
  test "sms.message webhook marks matching automation message as delivered" do
    Account.current = nil

    account = Account.create!(name: "Admin Account", admin: true)
    Moizvonki.create!(
      account: account,
      domain: "test",
      user_name: "user@mail.ru",
      api_key: "api_key",
      webhook_secret: "secret123"
    )

    rule = AutomationRule.create!(
      account: account,
      title: "Rule",
      event: "incase.created",
      condition_type: "simple",
      active: true,
      delay_seconds: 0
    )

    action = AutomationAction.create!(
      automation_rule: rule,
      kind: "send_sms_moizvonki",
      value: "1"
    )

    client = Client.create!(account: account, name: "Test", phone: "+79991234567")
    msg = AutomationMessage.create!(
      account: account,
      automation_rule: rule,
      automation_action: action,
      client: client,
      channel: "sms",
      status: "sent",
      content: "Hello!",
      sent_at: Time.current,
      provider: "moizvonki"
    )

    payload = {
      webhook: { action: "sms.message", account_id: account.id.to_s },
      event: { event_type: 32, direction: 1, client_number: "+79991234567", text: "Hello!" }
    }

    post "/api/webhooks/moizvonki/#{account.id}/secret123", params: payload, as: :json

    assert_response :success
    msg.reload
    assert_equal "delivered", msg.status
    assert_not_nil msg.delivered_at
  end
end

