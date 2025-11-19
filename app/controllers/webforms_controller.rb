class WebformsController < ApplicationController
  include OffcanvasResponder
  include ActionView::RecordIdentifier
  
  before_action :set_webform, only: [:show, :edit, :update, :destroy, :schema, :preview, :build]

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
    @webform = current_account.webforms.build(webform_params)
    
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
    respond_to do |format|
      if @webform.update(webform_params)
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
    respond_to do |format|
      if @webform.update(webform_params)
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
    params.require(:webform).permit(:title, :kind, :status, settings: {})
  end
end

