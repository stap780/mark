class MessageTemplatesController < ApplicationController
  include OffcanvasResponder
  include ActionView::RecordIdentifier

  before_action :set_message_template, only: [:show, :edit, :update, :destroy]

  def index
    @message_templates = current_account.message_templates.order(:created_at)
  end

  def new
    @message_template = current_account.message_templates.build
  end

  def create
    @message_template = current_account.message_templates.build(message_template_params)

    respond_to do |format|
      if @message_template.save
        @preview_context = build_preview_context
        flash.now[:success] = t('.success')
        format.html { redirect_to account_message_template_path(current_account, @message_template) }
        format.turbo_stream { redirect_to edit_account_message_template_path(current_account, @message_template, format: :html) }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def show
    @preview_context = build_preview_context
  end

  def edit; end

  def update
    respond_to do |format|
      if @message_template.update(message_template_params)
        @preview_context = build_preview_context
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            dom_id(current_account, dom_id(@message_template, :preview)),
            partial: "message_templates/preview",
            locals: { message_template: @message_template, preview_context: @preview_context }
          )
        end
        format.html { redirect_to account_message_template_path(current_account, @message_template) }
      else
        format.turbo_stream do
          flash.now[:notice] = @message_template.errors.full_messages.join(' ')
          render turbo_stream: [
            # turbo_stream.update(
            #   dom_id(current_account, dom_id(@message_template, :form)),
            #   partial: "message_templates/form",
            #   locals: { message_template: @message_template, current_account: current_account }
            # ),
            render_turbo_flash
          ]
        end
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @message_template.destroy
    respond_to do |format|
      flash.now[:success] = t('.success')
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove( dom_id(@message_template, dom_id(current_account))),
          render_turbo_flash
        ]
      end
      format.html { redirect_to account_message_templates_path(current_account), notice: t('.success') }
    end
  end

  private

  def set_message_template
    @message_template = current_account.message_templates.find(params[:id])
  end

  def message_template_params
    params.require(:message_template).permit(:title, :channel, :subject, :content, :context)
  end

  def build_preview_context
    # Для предпросмотра всегда используем фейковые объекты,
    # но их интерфейс должен соответствовать тому, что ожидают LiquidDrops.
    require 'ostruct'

    # Фейковые товары (нужны title и product_link через IncaseItemDrop#product_link)
    fake_product1 = OpenStruct.new(
      title: 'Тестовый товар 1',
      insales_link: '/product_by_id/12345'
    )
    fake_product2 = OpenStruct.new(
      title: 'Тестовый товар 2',
      insales_link: '/product_by_id/67890'
    )

    # Фейковые варианты (нужны для variant.quantity)
    fake_variant1 = OpenStruct.new(
      id: 1,
      quantity: 5,
      price: 100,
      sku: 'TEST-1',
      barcode: '1234567890123',
      product: fake_product1
    )
    fake_variant2 = OpenStruct.new(
      id: 2,
      quantity: 3,
      price: 300,
      sku: 'TEST-2',
      barcode: '1234567890124',
      product: fake_product2
    )

    # Фейковые позиции заявки (item)
    fake_item1 = OpenStruct.new(product: fake_product1, variant: fake_variant1, quantity: 2, price: 100, sum: 200)
    fake_item2 = OpenStruct.new(product: fake_product2, variant: fake_variant2, quantity: 1, price: 300, sum: 300)

    # Фейковая заявка
    fake_incase = OpenStruct.new(
      id: 12345,
      display_number: 12345,
      status: 'in_progress',
      created_at: Time.current,
      items: [fake_item1, fake_item2]
    )

    # Фейковый клиент
    fake_client = OpenStruct.new(
      name: 'Иван Иванов',
      email: 'ivan@example.com',
      phone: '+7 (999) 123-45-67'
    )

    # Для совместимости с ClientDrop: incases и incases_for_notify
    fake_client.define_singleton_method(:incases) do
      @incases ||= [fake_incase]
    end

    fake_client.define_singleton_method(:incases_for_notify) do
      incases
    end

    # Фейковая вебформа
    fake_webform = OpenStruct.new(
      title: 'Тестовая форма заказа',
      kind: 'notify'
    )

    # Создаем вторую фейковую заявку для демонстрации нескольких заявок
    fake_incase2 = OpenStruct.new(
      id: 12346,
      display_number: 12346,
      status: 'in_progress',
      created_at: Time.current,
      items: [fake_item2]
    )

    Automation::LiquidContextBuilder.build(
      incase: fake_incase,
      client: fake_client,
      client_incases: [fake_incase, fake_incase2], # Передаем все заявки клиента
      webform: fake_webform
    )
  end

end
