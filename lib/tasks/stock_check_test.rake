namespace :stock_check do
  desc "Run StockCheck + IncaseNotifyGroupByClient for given account (default: 2) to test scenario 3"
  task :test_scenario3, [:account_id] => :environment do |_, args|
    account_id = (args[:account_id] || ENV["ACCOUNT_ID"] || 2).to_i

    account = Account.find_by(id: account_id)
    unless account
      puts "Account ##{account_id} not found"
      exit 1
    end

    puts "=== Scenario 3 test for Account ##{account.id} (#{account.name}) ==="

    notify_webform = account.webforms.find_by(kind: "notify")
    if notify_webform
      statuses_before = account.incases.where(webform: notify_webform).group(:status).count
      puts "Notify incases before StockCheck: #{statuses_before.inspect}"
    else
      puts "No notify webform found for this account"
    end

    puts "\n-- Running StockCheck..."
    success, result = StockCheck.new(account).call
    puts "StockCheck success: #{success}"
    puts "StockCheck result:  #{result.inspect}"

    if notify_webform
      statuses_after_stock = account.incases.where(webform: notify_webform).group(:status).count
      puts "Notify incases after StockCheck: #{statuses_after_stock.inspect}"
    end

    puts "\n-- Running IncaseNotifyGroupByClient..."
    notify_success, notify_result = IncaseNotifyGroupByClient.new(account).call
    puts "IncaseNotifyGroupByClient success: #{notify_success}"
    puts "IncaseNotifyGroupByClient result:  #{notify_result.inspect}"

    if notify_webform
      statuses_after_notify = account.incases.where(webform: notify_webform).group(:status).count
      puts "Notify incases after IncaseNotifyGroupByClient: #{statuses_after_notify.inspect}"
    end

    messages_scope = account.automation_messages
    messages_scope = messages_scope.where(automation_rule_id: ENV["RULE_ID"]) if ENV["RULE_ID"].present?
    count = messages_scope.count
    puts "\nAutomationMessages count#{ENV['RULE_ID'] ? " for RULE_ID=#{ENV['RULE_ID']}" : ""}: #{count}"
  end
end


