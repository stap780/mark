account1 = Account.find_or_create_by!(name: "Default Account")

admin1 = User.find_or_initialize_by(email_address: "admin@example.com")
admin1.assign_attributes(account: account1, password: "password", password_confirmation: "password", role: "admin")
admin1.save!
puts "Seeded account=#{account1.name} (id=#{account1.id}), admin user=#{admin1.email_address} / password=password"


account2 = Account.find_or_create_by!(name: "Second Account")
admin2 = User.find_or_initialize_by(email_address: "admin2@example.com")
admin2.assign_attributes(account: account2, password: "password", password_confirmation: "password", role: "admin")
admin2.save!
puts "Seeded account=#{account2.name} (id=#{account2.id}), admin user=#{admin2.email_address} / password=password"
