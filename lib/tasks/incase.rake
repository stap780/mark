# frozen_string_literal: true

namespace :incase do
  desc "Create incase type order with sample InSales-style data (account 2, client wata, one order line)"
  task create_order: :environment do
    data = {
      order_lines: [
        {
          id: 1077425841,
          order_id: 1229723873,
          sale_price: 78.13,
          full_sale_price: 78.13,
          total_price: 78.13,
          full_total_price: 78.13,
          discounts_amount: 0.0,
          quantity: 1,
          reserved_quantity: 1,
          variant_id: 402703395,
          product_id: 235134198,
          sku: "5399-829-309",
          title: "Jabra Evolve 30 II UC Stereo компьютерная гарнитура с разъемом 3.5мм-USB ( 5399-829-309 )"
        }
      ],
      client: {
        id: 74489151,
        email: "wata@mail.ru",
        name: "wata",
        phone: "+79171232323"
      },
      number: 1059
    }

    account = Account.find(2)
    Account.switch_to(account.id)

    incase = InsalesOrderIncaseCreator.call(account: account, order_data: data)
    puts "Created incase ##{incase.id} (display_number: #{incase.display_number}, number: #{incase.number})"
  rescue InsalesOrderIncaseCreator::Error => e
    puts "Error: #{e.message}"
    exit 1
  rescue ActiveRecord::RecordInvalid => e
    puts "Validation failed: #{e.record.errors.full_messages}"
    exit 1
  end
end
