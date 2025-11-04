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
