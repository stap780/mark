class Incase < ApplicationRecord
  include AccountScoped
  include ActionView::RecordIdentifier
  include Varbindable

  belongs_to :account
  belongs_to :webform
  belongs_to :client
  belongs_to :incase_status

  has_many :items, dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true
  has_many :automation_messages

  validates :incase_status_id, presence: true

  delegate :key, :name, :color, to: :incase_status, prefix: false

  # Для обратной совместимости: status возвращает key (new, in_progress, done, canceled, closed)
  def status
    incase_status&.key
  end

  def status_color
    incase_status&.color || "bg-gray-100 text-gray-800"
  end

  # Генерируем порядковый номер для отображения пользователю
  # (number используется для номеров из API/InSales и может быть строковым)
  before_create :generate_display_number, unless: :display_number?
  before_destroy :check_automation_messages_dependency
  after_update_commit :trigger_update_events

  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[webform client incase_status]
  end

  def broadcast_target_for_varbinds
    [account, [self, :varbinds]]
  end

  def broadcast_target_id_for_varbinds
    dom_id(account, dom_id(self, :varbinds))
  end

  def broadcast_locals_for_varbind(varbind)
    { incase: self, varbind: varbind }
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


