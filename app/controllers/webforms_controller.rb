class WebformsController < ApplicationController
  include OffcanvasResponder
  include ActionView::RecordIdentifier
  
  before_action :set_webform, only: [:show, :edit, :update, :destroy, :schema, :preview, :build, :design, :trigger_value_field]

  def index
    @webforms = current_account.webforms.order(created_at: :asc)
  end

  def show
    @schema = Webforms::BuildSchema.new(@webform).call
  end

  def new
    @webform = current_account.webforms.build
  end

  def create
    # Обрабатываем target_pages и exclude_pages из textarea (строки с переносами -> массивы)
    processed_params = webform_params.dup
    if processed_params[:settings].present?
      if processed_params[:settings][:target_pages].is_a?(String)
        processed_params[:settings][:target_pages] = processed_params[:settings][:target_pages].split("\n").map(&:strip).reject(&:blank?)
      end
      if processed_params[:settings][:exclude_pages].is_a?(String)
        processed_params[:settings][:exclude_pages] = processed_params[:settings][:exclude_pages].split("\n").map(&:strip).reject(&:blank?)
      end
    end
    
    @webform = current_account.webforms.build(processed_params)
    
    respond_to do |format|
      if @webform.save
        WebformJsonGeneratorJob.perform_later(current_account.id)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              dom_id(current_account, :webforms),
              partial: "webforms/webform",
              locals: { current_account: current_account, webform: @webform }
            )
          ]
        end
        format.html { redirect_to account_webform_path(current_account, @webform), notice: t('.success') }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    # Обрабатываем target_pages и exclude_pages из textarea (строки с переносами -> массивы)
    processed_params = webform_params.dup
    if processed_params[:settings].present?
      if processed_params[:settings][:target_pages].is_a?(String)
        processed_params[:settings][:target_pages] = processed_params[:settings][:target_pages].split("\n").map(&:strip).reject(&:blank?)
      end
      if processed_params[:settings][:exclude_pages].is_a?(String)
        processed_params[:settings][:exclude_pages] = processed_params[:settings][:exclude_pages].split("\n").map(&:strip).reject(&:blank?)
      end
    end
    
    respond_to do |format|
      if @webform.update(processed_params)
        WebformJsonGeneratorJob.perform_later(current_account.id)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(current_account, dom_id(@webform)),
              partial: "webforms/webform",
              locals: { current_account: current_account, webform: @webform }
            )
          ]
        end
        format.html { redirect_to account_webform_path(current_account, @webform), notice: t('.success') }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def build
    # Обрабатываем target_pages и exclude_pages из textarea (строки с переносами -> массивы)
    processed_params = webform_params.dup
    if processed_params[:settings].present?
      settings_hash = processed_params[:settings]
      # На случай, если здесь всё ещё ActionController::Parameters
      settings_hash = settings_hash.to_unsafe_h if settings_hash.is_a?(ActionController::Parameters)

      # target_pages / exclude_pages: textarea -> массив строк
      if settings_hash[:target_pages].is_a?(String)
        settings_hash[:target_pages] = settings_hash[:target_pages].split("\n").map(&:strip).reject(&:blank?)
      end
      if settings_hash[:exclude_pages].is_a?(String)
        settings_hash[:exclude_pages] = settings_hash[:exclude_pages].split("\n").map(&:strip).reject(&:blank?)
      end

      # ВАЖНО: не затираем существующие настройки (в т.ч. триггеры),
      # а накладываем новые дизайн-настройки поверх старого хеша.
      current_settings = (@webform.settings || {}).with_indifferent_access
      merged_settings  = current_settings.merge(settings_hash)
      processed_params[:settings] = merged_settings
    end
    
    respond_to do |format|
      if @webform.update(processed_params)
        @schema = Webforms::BuildSchema.new(@webform).call
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream:
            turbo_stream.update(
              dom_id(current_account, dom_id(@webform, :preview)),
              partial: "webforms/preview",
              locals: { schema: @schema }
            )
        end
        format.html { redirect_to account_webform_path(current_account, @webform), notice: t('.success') }
      end
    end
  end 

  def destroy
    check_destroy = @webform.destroy ? true : false
    if check_destroy == true
      WebformJsonGeneratorJob.perform_later(current_account.id)
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @webform.errors.full_messages.join(" ")
    end
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          render_turbo_flash
        ]
      end
      format.html { redirect_to account_webforms_path(current_account), notice: t('.success')}
      format.json { head :no_content }
    end
  end

  def schema
    schema = Webforms::BuildSchema.new(@webform).call
    render json: schema
  end

  def preview
    @schema = Webforms::BuildSchema.new(@webform).call
    render :preview
  end

  def design; end

  def trigger_value_field
    @trigger_type = params[:trigger_type] || @webform.trigger_type.presence || Webform.default_trigger_type_for_kind(@webform.kind)
    
    # Turbo Frame автоматически обработает ответ
  end

  def info; end

  def regenerate_json
    WebformJsonGeneratorJob.perform_later(current_account.id)
    redirect_to account_webforms_path(current_account), notice: t('.regenerated')
  end

  private

  def set_webform
    @webform = current_account.webforms.find(params[:id])
  end

  def webform_params
    permitted = params.require(:webform).permit(
      :title,
      :kind,
      :status,
      :show_times,
      :trigger_type,
      :trigger_value,
      :show_delay,
      :show_once_per_session,
      :show_frequency_days,
      :target_pages,
      :exclude_pages,
      :target_devices,
      :cookie_name,
      settings: {}
    )

    # Преобразуем settings в обычный хеш, чтобы можно было свободно хранить
    # как дизайн-настройки (width, border_radius и т.п.), так и настройки триггеров.
    if permitted[:settings].is_a?(ActionController::Parameters)
      permitted[:settings] = permitted[:settings].to_unsafe_h
    end

    permitted
  end
end

