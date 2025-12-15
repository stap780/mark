class Incase < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :webform
  belongs_to :client

  has_many :items, dependent: :destroy

  enum :status, {
    new: "new",
    in_progress: "in_progress",
    done: "done",
    canceled: "canceled",
    closed: "closed"
  }, prefix: true

  validates :status, presence: true

  after_create_commit :trigger_created_event
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

  def trigger_created_event
    event = "incase.created.#{webform.kind}"
    Automation::Engine.call(
      account: account,
      event: event,
      object: self
    )
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


