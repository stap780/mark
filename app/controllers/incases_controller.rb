class IncasesController < ApplicationController
  include ActionView::RecordIdentifier
  
  before_action :set_incase, only: [:show, :update_status, :destroy]

  def new
    default_status = current_account.incase_statuses.find_by(key: "new") || current_account.incase_statuses.first
    @incase = current_account.incases.build(client_id: params[:client_id], incase_status: default_status)
    @active_webforms = current_account.webforms.status_active.order(:title)
    @client = current_account.clients.find_by(id: params[:client_id])
  end

  def create
    default_status = current_account.incase_statuses.find_by(key: "new") || current_account.incase_statuses.first
    @incase = current_account.incases.build(incase_params.merge(incase_status: default_status))
    if @incase.save
      flash.now[:notice] = t('.success')
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [render_turbo_flash], status: :see_other
        end
        format.html { redirect_to account_incase_path(current_account, @incase), notice: t('.success'), status: :see_other }
      end
    else
      @active_webforms = current_account.webforms.status_active.order(:title)
      @client = @incase.client
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(:new_incase_form, partial: "incases/form", locals: { incase: @incase, active_webforms: @active_webforms, client: @client }), status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def index
    q_params = params[:q] || {}
    q_params = q_params.merge(webform_id_eq: params[:webform_id]) if params[:webform_id].present?

    @search = current_account.incases.includes(:client, :webform, :incase_status).ransack(q_params)
    @search.sorts = "created_at desc" if @search.sorts.empty?
    @incases = @search.result(distinct: true).paginate(page: params[:page], per_page: 50)
    @webforms = current_account.webforms.order(:title)

    days_count = (params[:chart_days] || 14).to_i.clamp(7, 30)
    base_scope = current_account.incases
    effective_webform_id = params[:webform_id].presence || params.dig(:q, :webform_id_eq)
    base_scope = base_scope.where(webform_id: effective_webform_id) if effective_webform_id.present?
    @chart_data = build_chart_data(base_scope, days_count)
  end

  def show; end

  def update_status
    new_status = current_account.incase_statuses.find_by(key: params.require(:status)) ||
                 current_account.incase_statuses.find_by(id: params.require(:status))
    respond_to do |format|
      if new_status && @incase.update(incase_status: new_status)
        format.turbo_stream do
          flash.now[:success] = t('.success')
          render turbo_stream: [
            turbo_stream.update(dom_id(current_account, dom_id(@incase, :status)), partial: "incases/status", locals: { incase: @incase }),
            render_turbo_flash
          ]
        end
        format.html { redirect_to account_incase_path(current_account, @incase), notice: 'Status updated' }
      else
        format.turbo_stream do
          flash.now[:alert] = @incase.errors.full_messages.join(', ')
          render turbo_stream: [render_turbo_flash]
        end
        format.html { redirect_to account_incase_path(current_account, @incase), alert: @incase.errors.full_messages.join(', ') }
      end
    end
  end

  def destroy
    check_destroy = @incase.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t(".success")
    else
      flash.now[:notice] = @incase.errors.full_messages.join(" ")
    end

    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(current_account, dom_id(@incase))),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to account_incases_path(current_account), notice: t('.success') }
      format.json { head :no_content }
    end
  end

  private

  def set_incase
    @incase = current_account.incases.find(params[:id])
  end

  def incase_params
    params.require(:incase).permit(:incase_status_id, :webform_id, :client_id, :number, :display_number, custom_fields: {},
      items_attributes: %i[id quantity price product_id variant_id _destroy])
  end

  def build_chart_data(scope, days)
    labels = days.downto(0).map { |i| (Date.current - i).strftime("%d.%m") }
    data = days.downto(0).map do |i|
      date = Date.current - i
      scope.where(created_at: date.beginning_of_day..date.end_of_day).count
    end
    {
      labels: labels,
      datasets: [{
        label: t('incases.index.chart_label', default: 'Заявок'),
        backgroundColor: 'rgba(139, 92, 246, 0.2)',
        borderColor: '#7c3aed',
        data: data
      }]
    }
  end
end


