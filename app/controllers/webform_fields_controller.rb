class WebformFieldsController < ApplicationController
  include OffcanvasResponder
  include ActionView::RecordIdentifier
  
  before_action :set_webform
  before_action :set_webform_field, only: [:edit, :update, :destroy, :sort, :design, :build]

  def new
    @webform_field = @webform.webform_fields.build
  end

  def create
    @webform_field = @webform.webform_fields.build(webform_field_params)
    
    respond_to do |format|
      if @webform_field.save
        WebformJsonGeneratorJob.perform_later(current_account.id)
        @schema = Webforms::BuildSchema.new(@webform).call
        flash.now[:success] = t('.success')
        # puts "dom_id(current_account, dom_id(@webform, :webform_fields)): #{dom_id(current_account, dom_id(@webform, :webform_fields))}"
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              dom_id(current_account, dom_id(@webform, :webform_fields)),
              partial: "webform_fields/webform_field",
              locals: { current_account: current_account, webform: @webform, field: @webform_field }
            ),
            turbo_stream.update(
              dom_id(current_account, dom_id(@webform, :preview)),
              partial: "webforms/preview",
              locals: { schema: @schema }
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

  def design; end

  def build
    # Обрабатываем только settings, не затрагивая другие поля
    if params[:webform_field][:settings].present?
      current_settings = (@webform_field.settings || {}).with_indifferent_access
      new_settings = params[:webform_field][:settings]
      new_settings = new_settings.to_unsafe_h if new_settings.is_a?(ActionController::Parameters)
      merged_settings = current_settings.merge(new_settings)
      
      respond_to do |format|
        if @webform_field.update(settings: merged_settings)
          @schema = Webforms::BuildSchema.new(@webform).call
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update(
                dom_id(current_account, dom_id(@webform, :preview)),
                partial: "webforms/preview",
                locals: { schema: @schema }
              )
            ]
          end
          format.html { head :ok }
        else
          format.html { render :design, status: :unprocessable_entity }
        end
      end
    else
      head :ok
    end
  end

  def update
    respond_to do |format|
      if @webform_field.update(webform_field_params)
        WebformJsonGeneratorJob.perform_later(current_account.id)
        @schema = Webforms::BuildSchema.new(@webform).call
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(current_account, dom_id(@webform_field)),
              partial: "webform_fields/webform_field",
              locals: { account: current_account, webform: @webform, field: @webform_field }
            ),
            turbo_stream.update(
              dom_id(current_account, dom_id(@webform, :preview)),
              partial: "webforms/preview",
              locals: { schema: @schema }
            )
          ]
        end
        format.html { redirect_to account_webform_path(current_account, @webform), notice: t('.success') }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            :offcanvas,
            partial: "webform_fields/design"
          ), status: :unprocessable_entity
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @webform_field.destroy
    WebformJsonGeneratorJob.perform_later(current_account.id)
    respond_to do |format|
      format.turbo_stream do
        @schema = Webforms::BuildSchema.new(@webform).call
        flash.now[:success] = t('.success')
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.remove(
            dom_id(current_account, dom_id(@webform_field))
          ),
          turbo_stream.update(
            dom_id(current_account, dom_id(@webform, :preview)),
            partial: "webforms/preview",
            locals: { schema: @schema }
          )
        ]
      end
      format.html { redirect_to account_webform_path(current_account, @webform), notice: t('.success') }
    end
  end

  def sort
    @webform_field.insert_at(params[:position].to_i)
    @webform.reload # Перезагружаем webform чтобы получить обновлённый порядок полей
    WebformJsonGeneratorJob.perform_later(current_account.id)
    @schema = Webforms::BuildSchema.new(@webform).call
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          dom_id(current_account, dom_id(@webform, :preview)),
          partial: "webforms/preview",
          locals: { schema: @schema }
        )
      end
      format.json { head :ok }
      format.html { head :ok }
    end
  end

  private

  def set_webform
    @webform = current_account.webforms.find(params[:webform_id])
  end

  def set_webform_field
    @webform_field = @webform.webform_fields.find(params[:id])
  end

  def webform_field_params
    permitted = params.require(:webform_field).permit(:name, :label, :field_type, :required, :position, :image, :select_options, settings: {})
    
    # Handle settings hash from form
    if params[:webform_field][:settings].is_a?(ActionController::Parameters)
      permitted[:settings] = params[:webform_field][:settings].to_unsafe_h
    elsif permitted[:settings].present? && permitted[:settings].is_a?(String)
      permitted[:settings] = JSON.parse(permitted[:settings]) rescue permitted[:settings]
    end
    
    permitted
  end
  
end

