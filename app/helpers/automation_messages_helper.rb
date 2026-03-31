# frozen_string_literal: true

module AutomationMessagesHelper
  # [label, tailwind color classes] — синхронизировать с AutomationMessage.statuses
  STATUS_BADGES = {
    "pending" => ["Ожидает", "bg-yellow-100 text-yellow-800"],
    "sent" => ["Отправлено", "bg-green-100 text-green-800"],
    "failed" => ["Ошибка", "bg-red-100 text-red-800"],
    "delivered" => ["Доставлено", "bg-blue-100 text-blue-800"],
    "email_fbl" => ["Жалоба (FBL)", "bg-orange-100 text-orange-800"],
    "email_unsubscribe" => ["Отписка", "bg-purple-100 text-purple-800"],
    "email_open" => ["Открыто", "bg-emerald-100 text-emerald-800"],
    "email_click" => ["Клик по ссылке", "bg-teal-100 text-teal-800"]
  }.freeze

  def automation_message_status_badge(message)
    key = message.status.to_s
    label, classes = STATUS_BADGES.fetch(key) do
      [key.tr("_", " ").humanize, "bg-gray-100 text-gray-800"]
    end
    tag.span(label, class: "px-2 py-1 text-xs #{classes} rounded")
  end
end
