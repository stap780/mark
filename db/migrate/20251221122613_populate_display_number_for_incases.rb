class PopulateDisplayNumberForIncases < ActiveRecord::Migration[8.0]
  def up
    # Для каждого аккаунта отдельно заполняем display_number
    Account.find_each do |account|
      # Находим максимальный display_number для аккаунта
      max_display_number = account.incases
        .where.not(display_number: nil)
        .maximum(:display_number) || 0
      
      # Находим все заявки без display_number, отсортированные по дате создания
      incases_without_number = account.incases
        .where(display_number: nil)
        .order(:created_at, :id)
      
      # Присваиваем порядковые номера начиная с max + 1
      incases_without_number.each_with_index do |incase, index|
        incase.update_column(:display_number, max_display_number + index + 1)
      end
    end
  end

  def down
    # Не можем откатить это изменение, так как не знаем какие номера были сгенерированы
    # Оставляем display_number как есть
  end
end
