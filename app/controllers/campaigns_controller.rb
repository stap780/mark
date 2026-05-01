# frozen_string_literal: true

class CampaignsController < ApplicationController
  include OffcanvasResponder
  include ActionView::RecordIdentifier

  helper CampaignFilterRulesHelper

  before_action :set_campaign, only: %i[show edit update destroy start stop]

  def index
    @campaigns = current_account.campaigns.includes(:campaign_filter_rules).order(created_at: :desc)
  end

  def info; end

  def new
    @campaign = current_account.campaigns.new
  end

  def show
    redirect_to edit_account_campaign_path(current_account, @campaign)
  end

  def create
    @campaign = current_account.campaigns.build(campaign_params)
    respond_to do |format|
      if @campaign.save
        # flash.now[:success] = t('.success')
        # format.turbo_stream { redirect_to edit_account_campaign_path(current_account, @campaign, format: :html) }
        format.html { redirect_to edit_account_campaign_path(current_account, @campaign), status: :see_other, notice: t('.success') }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    if @campaign.update(campaign_params)
      respond_to do |format|
        format.html { redirect_to edit_account_campaign_path(current_account, @campaign), notice: t(".success") }
        format.turbo_stream { redirect_to account_campaigns_path(current_account, format: :html), status: :see_other }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream do
          flash.now[:alert] = @campaign.errors.full_messages.join(", ")
          render turbo_stream: render_turbo_flash, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    check_destroy = @campaign.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t(".success")
    else
      flash.now[:notice] = @campaign.errors.full_messages.join(" ")
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy
          render turbo_stream: [
            turbo_stream.remove(dom_id(@campaign, dom_id(current_account))),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to account_campaigns_path(current_account), notice: t('.success'), status: :see_other }
      format.json { head :no_content }
    end
  end

  def start
    if @campaign.recurring? && @campaign.time.blank?
      redirect_to edit_account_campaign_path(current_account, @campaign), alert: t("campaigns.start.need_time")
      return
    end

    @campaign.start!
    message = t("campaigns.start.started")
    flash[:success] = message
    redirect_to account_campaigns_path(current_account), notice: message
  end

  def stop
    @campaign.stop!
    message = t("campaigns.stop.stopped")
    flash[:success] = message
    redirect_to account_campaigns_path(current_account), notice: message
  end

  private

  def set_campaign
    @campaign = current_account.campaigns.find(params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(
      :title, :webform_id, :recurring, :time, :dedupe_days, :notes, :recurrence, :active
    )
  end
end
