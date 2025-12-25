class Incase < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :webform
  belongs_to :client

  has_many :items, dependent: :destroy
  has_many :automation_messages

  enum :status, {
    new: "new",
    in_progress: "in_progress",
    done: "done",
    canceled: "canceled",
    closed: "closed"
  }, prefix: true

  validates :status, presence: true

  # Генерируем порядковый номер для отображения пользователю
  # (number используется для номеров из API/InSales и может быть строковым)
  before_create :generate_display_number, unless: :display_number?
  before_destroy :check_automation_messages_dependency
  after_update_commit :trigger_update_events

  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[webform client]
  end

  # Проверяет, есть ли у клиента заказ с такими же позициями
  # Используется в автоматизации для брошенных корзин
  def has_order_with_same_items?
    return false unless webform.kind == 'abandoned_cart'
    
    # Находим вебформу типа "заказ"
    order_webform = account.webforms.find_by(kind: 'order')
    return false unless order_webform
    
    # Получаем все заказы клиента
    orders = client.incases.where(webform: order_webform)
    return false if orders.empty?
    
    # Создаем хеш позиций брошенной корзины: { variant_id => quantity }
    cart_items_hash = items.group_by { |i| i.variant_id }
                          .transform_values { |items| items.sum(&:quantity) }
    
    # Проверяем каждый заказ
    orders.any? do |order|
      # Создаем хеш позиций заказа
      order_items_hash = order.items.group_by { |i| i.variant_id }
                                  .transform_values { |items| items.sum(&:quantity) }
      
      # Сравниваем хеши
      cart_items_hash == order_items_hash
    end
  end

  private

  def check_automation_messages_dependency
    return unless automation_messages.exists?

    errors.add(:base, I18n.t('incases.destroy.has_automation_messages'))
    throw(:abort)
  end

  def generate_display_number
    # Генерируем порядковый номер для отображения пользователю
    # Номер генерируется отдельно для каждого аккаунта
    max_display_number = account.incases
      .where.not(display_number: nil)
      .maximum(:display_number)
    
    if max_display_number.present?
      # Увеличиваем на 1
      self.display_number = max_display_number + 1
    else
      # Если это первая заявка для аккаунта, начинаем с 1
      self.display_number = 1
    end
  end

  def trigger_update_events
    # Вызываем incase.updated при любом обновлении заявки
    Automation::Engine.call(
      account: account,
      event: "incase.updated",
      object: self
    )
  end
end


