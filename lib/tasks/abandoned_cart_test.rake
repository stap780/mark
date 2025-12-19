namespace :abandoned_cart do
  desc "Check Scenario 4 test result (abandoned cart email)"
  task :check_result, [:account_id] => :environment do |_, args|
    account_id = (args[:account_id] || ENV["ACCOUNT_ID"] || 2).to_i
    account = Account.find_by(id: account_id)
    unless account
      puts "Account ##{account_id} not found"
      exit 1
    end

    rule = account.automation_rules.find_by(event: 'incase.created.abandoned_cart', delay_seconds: 180)
    unless rule
      puts "Rule not found"
      exit 1
    end

    puts "=== Scenario 4 Test Result ==="
    puts "Rule ID: #{rule.id}"
    puts "Delay: #{rule.delay_seconds} seconds"
    puts "Scheduled for: #{rule.scheduled_for}"
    puts "Current time: #{Time.zone.now}"
    
    if rule.scheduled_for
      time_until = (rule.scheduled_for - Time.zone.now).to_i
      if time_until > 0
        puts "Time until execution: #{time_until} seconds (#{(time_until / 60.0).round(1)} minutes)"
      else
        puts "Should have executed #{time_until.abs} seconds ago"
      end
    end

    puts "\n--- Automation Messages ---"
    messages = account.automation_messages.where(automation_rule: rule).order(created_at: :desc).limit(5)
    if messages.any?
      messages.each do |msg|
        puts "ID: #{msg.id} | Status: #{msg.status} | Created: #{msg.created_at} | Sent: #{msg.sent_at || 'N/A'}"
        puts "Subject: #{msg.subject}"
        puts "Client: #{msg.client&.name} (#{msg.client&.email})"
        puts "---"
      end
      
      last_msg = messages.first
      if last_msg.status == 'sent'
        puts "\n✅ Email was sent successfully!"
        puts "Content preview (first 500 chars):"
        puts last_msg.content[0..500]
      elsif last_msg.status == 'pending'
        puts "\n⏳ Email is pending (not sent yet)"
      elsif last_msg.status == 'failed'
        puts "\n❌ Email failed: #{last_msg.error_message}"
      end
    else
      puts "No messages found yet. Task may not have executed yet."
    end
  end
end

