class ConversationsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_account
  before_action :set_client, only: [:send_message], if: -> { params[:client_id].present? }
  before_action :set_conversation, only: [:show, :send_message, :close, :reopen]

  def index
    q = (params[:q] || {}).stringify_keys
    if q["status_eq"].to_s == "all"
      q = q.except("status_eq")
    elsif q["status_eq"].to_s.blank?
      q = q.merge("status_eq" => "active")
    end
    @search = @account.conversations.includes(:client, :messages).ransack(q)
    @search.sorts = "last_message_at desc" if @search.sorts.empty?
    @conversations = @search.result(distinct: true).paginate(page: params[:page], per_page: 50)
  end

  def show
    @conversation.mark_as_read!
    @conversation.broadcast_list_item_update
    @messages = @conversation.messages.order(created_at: :asc).last(50)
    @client = @conversation.client
  end

  def new
    @clients = @account.clients.order(:name).limit(100)
  end

  def create
    client = @account.clients.find(params[:client_id])
    if client.telegram_block?
      flash.now[:alert] = t("conversations.create.telegram_blocked")
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_close_offcanvas_flash, status: :unprocessable_entity }
        format.html { redirect_to new_account_conversation_path(@account), alert: t("conversations.create.telegram_blocked"), status: :see_other }
      end
      return
    end
    # Используем только активный диалог по клиенту; если есть только закрытый/архивный — создаём новый
    @conversation = @account.conversations.active.find_by(client: client) ||
                    @account.conversations.create!(client: client, status: :active)
    @conversation.mark_as_read!
    @messages = @conversation.messages.order(created_at: :asc).last(50)
    @client = @conversation.client
    flash.now[:notice] = t("conversations.create.success")

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_close_offcanvas_flash + [
          turbo_stream.remove(dom_id(@account, :conversations_empty)),
          turbo_stream.prepend(dom_id(@account, :conversations), partial: "conversations/conversation", locals: { conversation: @conversation, current_account: @account }),
          turbo_stream.replace(dom_id(@account, :conversation), partial: "conversations/show_frame_content", locals: { conversation: @conversation, messages: @messages, client: @client, current_account: @account })
        ], status: :see_other
      end
      format.html { redirect_to account_conversation_path(@account, @conversation), status: :see_other }
    end
  end

  def send_message
    channel_param = params[:channel]
    content = params[:content]
    subject = params[:subject]

    # Парсим канал и SMS провайдер из параметра (формат: "telegram", "email", "sms:idgtl", "sms:moizvonki")
    channel, sms_provider = if channel_param&.start_with?('sms:')
      ['sms', channel_param.split(':').last]
    else
      [channel_param, nil]
    end

    respond_to do |format|
      unless channel.in?(%w[telegram email sms])
        flash.now[:alert] = "Неверный канал отправки"
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
        }
        redirect_path = @client ? account_client_path(@account, @client) : account_conversation_path(@account, @conversation)
        format.html { redirect_to redirect_path, alert: "Неверный канал отправки" }
        return
      end

      unless content.present?
        flash.now[:alert] = "Текст сообщения не может быть пустым"
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
        }
        redirect_path = @client ? account_client_path(@account, @client) : account_conversation_path(@account, @conversation)
        format.html { redirect_to redirect_path, alert: "Текст сообщения не может быть пустым" }
        return
      end

      if channel == 'email' && subject.blank?
        flash.now[:alert] = "Тема письма не может быть пустой"
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
        }
        redirect_path = @client ? account_client_path(@account, @client) : account_conversation_path(@account, @conversation)
        format.html { redirect_to redirect_path, alert: "Тема письма не может быть пустой" }
        return
      end

      result = ConversationServices::MessageSender.new(
        conversation: @conversation,
        channel: channel,
        content: content,
        subject: subject,
        sms_provider: sms_provider,
        user: Current.user
      ).call

      # Всегда обновляем timeline, чтобы показать новое сообщение (даже если оно failed)
      @messages = @conversation.messages.order(created_at: :asc).last(50)
      @client = @conversation.client
      
      if result[:ok]
        flash.now[:notice] = "Сообщение отправлено"
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.replace("flash", partial: "shared/flash"),
            turbo_stream.replace(dom_id(@account, dom_id(@conversation, :messages)), partial: "conversations/conversation_timeline", locals: { conversation: @conversation, messages: @messages, current_account: @account }),
            turbo_stream.replace(dom_id(@account, dom_id(@conversation, :send_message_form)), partial: "conversations/send_message_form", locals: { conversation: @conversation, current_account: @account })
          ]
        }
        redirect_path = @client ? account_client_path(@account, @client) : account_conversation_path(@account, @conversation)
        format.html { redirect_to redirect_path, notice: "Сообщение отправлено" }
      else
        flash.now[:alert] = "Ошибка отправки: #{result[:error]}"
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.replace("flash", partial: "shared/flash"),
            turbo_stream.replace(dom_id(@account, dom_id(@conversation, :messages)), partial: "conversations/conversation_timeline", locals: { conversation: @conversation, messages: @messages, current_account: @account }),
            turbo_stream.replace(dom_id(@account, dom_id(@conversation, :send_message_form)), partial: "conversations/send_message_form", locals: { conversation: @conversation, current_account: @account })
          ]
        }
        redirect_path = @client ? account_client_path(@account, @client) : account_conversation_path(@account, @conversation)
        format.html { redirect_to redirect_path, alert: "Ошибка отправки: #{result[:error]}" }
      end
    end
  end

  def close
    @conversation.update!(status: :closed)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = t("conversations.close.success")
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.remove(dom_id(@account, dom_id(@conversation))),
          turbo_stream.replace(dom_id(@account, :conversation), partial: "conversations/conversation_placeholder", locals: { current_account: @account })
        ], status: :see_other
      end
      format.html { redirect_to account_conversations_path(@account), notice: t("conversations.close.success"), status: :see_other }
    end
  end

  def reopen
    @conversation.update!(status: :active)
    @messages = @conversation.messages.order(created_at: :asc).last(50)
    @client = @conversation.client
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = t("conversations.reopen.success")
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.replace(dom_id(@account, dom_id(@conversation)), partial: "conversations/conversation", locals: { conversation: @conversation, current_account: @account }),
          turbo_stream.replace(dom_id(@account, :conversation), partial: "conversations/show_frame_content", locals: { conversation: @conversation, messages: @messages, client: @client, current_account: @account })
        ], status: :see_other
      end
      format.html { redirect_to account_conversation_path(@account, @conversation), notice: t("conversations.reopen.success"), status: :see_other }
    end
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end

  def set_client
    @client = @account.clients.find(params[:client_id]) if params[:client_id].present?
  end

  def set_conversation
    if params[:id]
      @conversation = @account.conversations.find(params[:id])
    elsif params[:client_id]
      @client ||= @account.clients.find(params[:client_id])
      @conversation = @account.conversations.active.find_by(client: @client)
      if @conversation.nil? && !@client.telegram_block?
        @conversation = @account.conversations.create!(client: @client, status: :active)
      elsif @conversation.nil? && @client.telegram_block?
        redirect_to account_conversations_path(@account), alert: t("conversations.create.telegram_blocked"), status: :see_other and return
      end
    end
  end

end
