account = Account.find_or_create_by!(name: "Admin Account", admin: true)
account_admin_user = User.find_or_initialize_by(email_address: "admin_account@example.com")
account_admin_user.assign_attributes(account: account, password: "password", password_confirmation: "password", role: "member")
account_admin_user.save!
puts "Seeded account=#{account.name} (id=#{account.id}), admin user=#{account_admin_user.email_address} / password=password"


account1 = Account.find_or_create_by!(name: "Default Account")
account1_admin_user = User.find_or_initialize_by(email_address: "admin@example.com")
account1_admin_user.assign_attributes(account: account1, password: "password", password_confirmation: "password", role: "admin")
account1_admin_user.save!
puts "Seeded account=#{account1.name} (id=#{account1.id}), admin user=#{account1_admin_user.email_address} / password=password"


account2 = Account.find_or_create_by!(name: "Second Account")
account2_admin_user = User.find_or_initialize_by(email_address: "admin2@example.com")
account2_admin_user.assign_attributes(account: account2, password: "password", password_confirmation: "password", role: "admin")
account2_admin_user.save!
puts "Seeded account=#{account2.name} (id=#{account2.id}), admin user=#{account2_admin_user.email_address} / password=password"
