class StockCheckSchedulesController < ApplicationController
  include ActionView::RecordIdentifier
  include OffcanvasResponder

  before_action :set_stock_check_schedule, only: %i[show edit update destroy run]

  def index
    @stock_check_schedules = current_account.stock_check_schedules.order(created_at: :desc)
  end

  def show; end

  def new
    @stock_check_schedule = current_account.stock_check_schedules.build
  end

  def edit; end

  def create
    @stock_check_schedule = current_account.stock_check_schedules.build(stock_check_schedule_params)

    respond_to do |format|
      if @stock_check_schedule.save
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "stock_check_schedules",
              partial: "stock_check_schedules/stock_check_schedule",
              locals: { stock_check_schedule: @stock_check_schedule }
            )
          ]
        end
        format.html { redirect_to account_stock_check_schedules_path(current_account), notice: t('.success') }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @stock_check_schedule.update(stock_check_schedule_params)
        message = t('.success')
        flash.now[:success] = message
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@stock_check_schedule),
              partial: "stock_check_schedules/stock_check_schedule",
              locals: { stock_check_schedule: @stock_check_schedule }
            )
          ]
        end
        format.html { redirect_to account_stock_check_schedules_path(current_account), notice: message }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @stock_check_schedule.destroy!

    respond_to do |format|
      message = t('.success')
      flash.now[:success] = message
      format.turbo_stream { 
        render turbo_stream: [
          turbo_stream.remove(dom_id(current_account, dom_id(@stock_check_schedule))),
          render_turbo_flash
        ]
      }
      format.html { redirect_to account_stock_check_schedules_path(current_account), notice: message }
    end
  end

  def run
    # Запускаем фонового джоба для немедленной проверки остатков по расписанию
    StockCheckScheduleJob.perform_later(@stock_check_schedule, Time.zone.now)

    respond_to do |format|
      message = t('.success', default: 'Проверка остатков запущена')
      flash.now[:success] = message

      format.turbo_stream do
        render turbo_stream: [
          render_turbo_flash
        ]
      end

      format.html do
        redirect_to account_stock_check_schedules_path(current_account), notice: message
      end
    end
  end

  private

  def set_stock_check_schedule
    @stock_check_schedule = current_account.stock_check_schedules.find(params[:id])
  end

  def stock_check_schedule_params
    params.require(:stock_check_schedule).permit(:active, :time, :recurrence)
  end

end
