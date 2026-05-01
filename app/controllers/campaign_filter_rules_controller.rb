# frozen_string_literal: true

class CampaignFilterRulesController < ApplicationController
  include ActionView::RecordIdentifier
  include OffcanvasResponder

  helper CampaignFilterRulesHelper

  before_action :set_campaign
  before_action :set_campaign_filter_rule, only: %i[edit update destroy refresh_form]

  def edit
    render layout: false if turbo_frame_request?
  end

  def new; end

  def create
    @campaign_filter_rule = @campaign.campaign_filter_rules.build(new_rule_attributes)
    @campaign_filter_rule.save

    respond_to do |format|
      flash.now[:success] = t("campaign_filter_rules.create.success")
      format.turbo_stream { render turbo_stream: turbo_streams_after_campaign_filter_rule_created }
      format.html do
        redirect_to edit_account_campaign_path(current_account, @campaign), notice: t("campaign_filter_rules.create.success")
      end
    end
  end

  def refresh_form
    if @campaign_filter_rule.update(campaign_filter_rule_params)
      render turbo_stream: [
        turbo_stream.replace(
          dom_id(current_account, dom_id(@campaign, dom_id(@campaign_filter_rule, :form))),
          partial: "campaign_filter_rules/form",
          locals: { campaign: @campaign, campaign_filter_rule: @campaign_filter_rule }
        )
      ]
    else
      flash.now[:alert] = @campaign_filter_rule.errors.full_messages.join(", ")
      render turbo_stream: render_turbo_flash, status: :unprocessable_entity
    end
  end

  def update
    if @campaign_filter_rule.update(campaign_filter_rule_params)
      flash.now[:success] = t(".success")
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(current_account, dom_id(@campaign, dom_id(@campaign_filter_rule))),
              partial: "campaign_filter_rules/campaign_filter_rule",
              locals: { campaign: @campaign, rule: @campaign_filter_rule }
            )
          ]
        end
        format.html { redirect_to edit_account_campaign_path(current_account, @campaign), notice: t(".success") }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = @campaign_filter_rule.errors.full_messages.join(", ")
          render turbo_stream: render_turbo_flash, status: :unprocessable_entity
        end
        format.html { render :edit, status: :unprocessable_entity, layout: false }
      end
    end
  end

  def destroy
    @campaign_filter_rule.destroy
    flash.now[:success] = t(".success")
    respond_to do |format|
      format.turbo_stream { render turbo_stream: [
        turbo_stream.remove(dom_id(current_account, dom_id(@campaign, dom_id(@campaign_filter_rule)))),
        render_turbo_flash
      ] }
      format.html { redirect_to edit_account_campaign_path(current_account, @campaign), notice: t(".success") }
    end
  end

  private

  def set_campaign
    @campaign = current_account.campaigns.find(params[:campaign_id])
  end

  def set_campaign_filter_rule
    @campaign_filter_rule = @campaign.campaign_filter_rules.find(params[:id])
  end

  def campaign_filter_rule_params
    params.require(:campaign_filter_rule).permit(:field, :operator, :value, :target)
  end

  def new_rule_attributes
    field = params[:field].presence || "client_email_marketing_opt_in"
    cfg = CampaignFilterRule::FIELD_CONFIG[field.to_s]
    operator = params[:operator].presence || (cfg ? cfg[:operators].first : "equals")
    value = params[:value].presence || default_rule_value(field)
    { field: field, operator: operator, value: value }
  end

  def turbo_streams_after_campaign_filter_rule_created
    streams = [
      render_turbo_flash,
      turbo_stream.append(
        dom_id(current_account, dom_id(@campaign, :campaign_filter_rules)),
        partial: "campaign_filter_rules/campaign_filter_rule",
        locals: { campaign: @campaign, rule: @campaign_filter_rule }
      )
    ]
    streams
  end

  def default_rule_value(field)
    case field.to_s
    when "incase_days_min" then "30"
    when "incase_days_max" then "36500"
    when "client_email_marketing_opt_in" then "true"
    else ""
    end
  end

end
