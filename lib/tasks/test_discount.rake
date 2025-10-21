namespace :discount do
  desc "Create sample discounts for testing"
  task create_samples: :environment do
    account = Account.first
    
    unless account
      puts "❌ No account found. Please create an account first."
      exit
    end
    
    puts "Creating sample discounts for account ##{account.id}..."
    
    # Удаляем старые тестовые скидки
    account.discounts.destroy_all
    
    # Скидка 1: 2 товара из "Мужская одежда" = скидка 500 руб
    d1 = account.discounts.create!(
      title: "Скидка за 2 товара из Мужской категории",
      rule: <<~LIQUID.strip,
        {% assign muj_coll = "" %}
        {% for item in order_lines %}
          {% if item.colls contains "Мужская одежда" %}
            {% assign muj_coll = muj_coll | append: "," | append: "Мужская одежда" %}
          {% endif %}
        {% endfor %}
        {% assign muj_coll_array = muj_coll | remove_first: "," | split: "," %}
        {% if order_lines.size == muj_coll_array.size and muj_coll_array.size == 2 %}do_work{%else%}false{% endif %}
      LIQUID
      shift: 500,
      points: "money",
      notice: "вам скидка за 2 товара из Мужской категории",
      position: 1
    )
    puts "✅ Created: #{d1.title}"
    
    # Скидка 2: 3 товара в корзине = скидка = самому дешевому товару
    d2 = account.discounts.create!(
      title: "Скидка за 3 товара = самый дешевый товар",
      rule: "{% if order_lines.size == 3 %}do_work_with_lower_price{% else %}false{% endif %}",
      shift: 0,
      points: "money",
      notice: "вам скидка в размере самого дешевого товара",
      position: 2
    )
    puts "✅ Created: #{d2.title}"
    
    # Скидка 3: общая сумма > 40000 = скидка 10%
    d3 = account.discounts.create!(
      title: "Скидка 10% при сумме > 40000",
      rule: "{% if total_price > 40000 %}do_work{% else %}false{% endif %}",
      shift: 4650,
      points: "money",
      notice: "вам скидка 10% за покупку на сумму более 40000 руб",
      position: 3
    )
    puts "✅ Created: #{d3.title}"
    
    puts "\n✅ Created #{account.discounts.count} sample discounts"
  end
  
  desc "Test discount calculation with sample data"
  task test: :environment do
    # Загружаем тестовые данные
    file_path = Rails.root.join('docs', 'discount_data.json')
    data = JSON.parse(File.read(file_path))
    
    puts "=" * 80
    puts "Testing Discount Calculation"
    puts "=" * 80
    
    # Находим первый аккаунт для теста (или создаем)
    account = Account.first
    
    unless account
      puts "❌ No account found. Please create an account first."
      exit
    end
    
    puts "\n📋 Account: #{account.id}"
    puts "📊 Available discounts: #{account.discounts.count}"
    
    account.discounts.order(:position).each do |d|
      puts "  - [#{d.position}] #{d.title}"
    end
    
    puts "\n📦 Test data:"
    puts "  - Order lines: #{data['order_lines'].count}"
    data['order_lines'].each do |line|
      puts "    • #{line['title']}: #{line['sale_price']} RUB (collections: #{line['colls'].join(', ')})"
    end
    puts "  - Total price: #{data['total_price']} RUB"
    puts "  - Lower price: #{data['lower_price']} RUB"
    
    puts "\n🔄 Running discount calculation..."
    puts "-" * 80
    
    result = Discounts::Calc.call(account: account, data: data)
    
    puts "\n✅ Result:"
    puts JSON.pretty_generate(result)
    puts "=" * 80
  end
  
  desc "Test case when no discount matches"
  task test_no_match: :environment do
    file_path = Rails.root.join('docs', 'discount_data_no_match.json')
    data = JSON.parse(File.read(file_path))
    
    account = Account.first
    
    unless account
      puts "❌ No account found."
      exit
    end
    
    puts "=" * 80
    puts "Testing: NO DISCOUNT SHOULD MATCH"
    puts "=" * 80
    
    puts "\n📋 Account: #{account.id}"
    puts "📊 Available discounts: #{account.discounts.count}"
    
    account.discounts.order(:position).each do |d|
      puts "  - [#{d.position}] #{d.title}"
    end
    
    puts "\n📦 Test data:"
    puts "  - Order lines: #{data['order_lines'].count}"
    data['order_lines'].each do |line|
      puts "    • #{line['title']}: #{line['sale_price']} RUB (collections: #{line['colls'].join(', ')})"
    end
    puts "  - Total price: #{data['total_price']} RUB"
    
    puts "\n🔄 Running discount calculation..."
    puts "-" * 80
    
    result = Discounts::Calc.call(account: account, data: data)
    
    puts "\n✅ Result:"
    puts JSON.pretty_generate(result)
    
    if result.is_a?(Hash) && (result[:errors] || result['errors'])
      puts "\n✅ CORRECT: No discount applied (as expected)"
    elsif result.is_a?(Hash) && (result[:discount] || result['discount'])
      puts "\n⚠️  WARNING: A discount was applied (unexpected!)"
    else
      puts "\n✅ CORRECT: No discount applied"
    end
    puts "=" * 80
  end
  
  desc "Test discount with custom account ID"
  task :test_account, [:account_id] => :environment do |t, args|
    account_id = args[:account_id] || Account.first&.id
    
    unless account_id
      puts "❌ No account ID provided and no accounts found."
      puts "Usage: rake discount:test_account[ACCOUNT_ID]"
      exit
    end
    
    account = Account.find_by(id: account_id)
    
    unless account
      puts "❌ Account with ID #{account_id} not found."
      exit
    end
    
    file_path = Rails.root.join('docs', 'discount_data.json')
    data = JSON.parse(File.read(file_path))
    
    puts "Testing discount for account: #{account.id}"
    result = Discounts::Calc.call(account: account, data: data)
    puts JSON.pretty_generate(result)
  end
end

