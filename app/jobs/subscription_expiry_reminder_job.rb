# frozen_string_literal: true

class SubscriptionExpiryReminderJob < ApplicationJob
  queue_as :subscription_expiry_reminder

  REMINDER_DAYS = [7, 3, 1].freeze

  def perform
    Rails.logger.info "[SubscriptionExpiryReminderJob] Starting at #{Time.current}"

    sent_count = 0
    REMINDER_DAYS.each do |days_left|
      target_date = days_left.days.from_now.to_date
      subscriptions = subscriptions_ending_on(target_date)

      subscriptions.find_each do |subscription|
        next unless should_send_reminder?(subscription, days_left)

        account = subscription.account
        account.users.where.not(email_address: [nil, ""]).find_each do |user|
          send_reminder(user, account, subscription, days_left)
          sent_count += 1
        end
      end
    end

    Rails.logger.info "[SubscriptionExpiryReminderJob] Completed. Sent #{sent_count} reminders."
  end

  private

  def subscriptions_ending_on(date)
    Subscription
      .joins(:account)
      .where(status: [:active, :trialing])
      .where(accounts: { partner: false })
      .where("DATE(subscriptions.current_period_end) = ?", date)
  end

  def should_send_reminder?(subscription, days_left)
    account = subscription.account
    period_end = subscription.current_period_end

    # Пропускаем, если есть другая активная подписка на следующий период
    has_renewal = account.subscriptions
      .where(status: [:active, :trialing])
      .where.not(id: subscription.id)
      .where("current_period_end > ?", period_end)
      .exists?

    !has_renewal
  end

  def send_reminder(user, account, subscription, days_left)
    subject = I18n.t(
      "subscription_expiry_reminder.subject",
      days: days_left,
      default: "Напоминание: подписка заканчивается через %{days} дн."
    )

    subscriptions_url = subscriptions_url_for(account)
    end_date = subscription.current_period_end&.strftime("%d.%m.%Y") || "—"
    body = I18n.t(
      "subscription_expiry_reminder.body",
      account_name: account.name,
      days: days_left,
      end_date: end_date,
      subscriptions_url: subscriptions_url
    )

    mailganer_client = MailganerClient::Client.new
    x_track_id = "sub-reminder-#{account.id}-#{subscription.id}-#{days_left}-#{Time.current.to_i}"

    mailganer_client.send_email_smtp_v1(
      type: "body",
      to: user.email_address,
      from: "info@teletri.ru",
      subject: subject,
      body: body,
      x_track_id: x_track_id
    )

    Rails.logger.info "[SubscriptionExpiryReminderJob] Sent #{days_left}-day reminder to #{user.email_address} (account ##{account.id})"
  rescue => e
    Rails.logger.error "[SubscriptionExpiryReminderJob] Failed to send to #{user.email_address}: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end

  def subscriptions_url_for(account)
    host = ENV.fetch("APP_HOST", "app.teletri.ru")
    Rails.application.routes.url_helpers.account_subscriptions_url(account, host: host)
  end

end
