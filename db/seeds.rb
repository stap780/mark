account = Account.find_or_create_by!(name: "Admin Account", admin: true)
user = User.find_or_initialize_by(email_address: "admin_account@example.com")
user.assign_attributes(password: "password", password_confirmation: "password")
user.save!
account_user = account.account_users.find_or_initialize_by(user: user)
account_user.role = "member"
account_user.save!
puts "Seeded account=#{account.name} (id=#{account.id}), user=#{user.email_address} / password=password"


account1 = Account.find_or_create_by!(name: "Default Account")
user1 = User.find_or_initialize_by(email_address: "admin@example.com")
user1.assign_attributes(password: "password", password_confirmation: "password")
user1.save!
account1_user = account1.account_users.find_or_initialize_by(user: user1)
account1_user.role = "admin"
account1_user.save!
puts "Seeded account=#{account1.name} (id=#{account1.id}), admin user=#{user1.email_address} / password=password"


account2 = Account.find_or_create_by!(name: "Second Account")
user2 = User.find_or_initialize_by(email_address: "admin2@example.com")
user2.assign_attributes(password: "password", password_confirmation: "password")
user2.save!
account2_user = account2.account_users.find_or_initialize_by(user: user2)
account2_user.role = "admin"
account2_user.save!
puts "Seeded account=#{account2.name} (id=#{account2.id}), admin user=#{user2.email_address} / password=password"

# Billing plans
Plan.find_or_create_by(name: "Basic") do |plan|
  plan.price = 1000
  plan.interval = "monthly"
  plan.active = true
  plan.trial_days = 0
end

Plan.find_or_create_by(name: "Pro") do |plan|
  plan.price = 3000
  plan.interval = "monthly"
  plan.active = true
  plan.trial_days = 7
end

Plan.find_or_create_by(name: "Enterprise") do |plan|
  plan.price = 10000
  plan.interval = "monthly"
  plan.active = true
  plan.trial_days = 14
end

puts "Seeded billing plans: Basic (1000₽), Pro (3000₽), Enterprise (10000₽)"

# Создание правила автоматизации для брошенной корзины
account1 = Account.find_by(name: "Default Account")
if account1
  # Создаем или находим шаблон сообщения для брошенной корзины
  template = account1.message_templates.find_or_create_by!(
    title: "Брошенная корзина",
    channel: "email"
  ) do |t|
    t.subject = "Вы забыли товары в корзине"
    t.content = <<~HTML
      <h2>Здравствуйте, {{ client.name }}!</h2>
      <p>Вы оставили товары в корзине, но не завершили заказ.</p>
      <p>Вот что вы выбрали:</p>
      <ul>
        {% for item in incase.items %}
        <li>{{ item.product.title }} - {{ item.quantity }} шт. - {{ item.price }}₽</li>
        {% endfor %}
      </ul>
      <p>Не упустите возможность приобрести эти товары!</p>
    HTML
  end

  # Создаем правило автоматизации
  rule = account1.automation_rules.find_or_create_by!(
    title: "Брошенная корзина (без заказа)",
    event: "incase.created.abandoned_cart"
  ) do |r|
    r.condition_type = "simple"
    r.active = true
    r.position = 1
    r.delay_seconds = 0
  end

  # Создаем условие: нет заказа с такими же позициями
  condition = rule.automation_conditions.find_or_create_by!(
    field: "incase.has_order_with_same_items?",
    operator: "is_false"
  ) do |c|
    c.value = ""
    c.position = 1
  end

  # Создаем действие: отправить email
  action = rule.automation_actions.find_or_create_by!(
    kind: "send_email"
  ) do |a|
    a.position = 1
  end
  # Устанавливаем template_id через виртуальный атрибут
  action.template_id = template.id
  action.save!

  # Обновляем JSON условие (вызывается через before_save callback)
  rule.save!

  puts "Created automation rule: '#{rule.title}' (id=#{rule.id})"
  puts "  - Event: #{rule.event}"
  puts "  - Condition: #{condition.field} #{condition.operator}"
  puts "  - Action: #{action.kind} (template_id=#{template.id})"
end
