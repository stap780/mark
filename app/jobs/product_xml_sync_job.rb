# frozen_string_literal: true

class ProductXmlSyncJob < ApplicationJob
  include ActionView::RecordIdentifier
  queue_as :product_xml_sync

  def perform(account_id)
    account = Account.find(account_id)
    Account.switch_to(account.id)

    ProductXmlSync.new(account).call

    insale = account.insales.first
    return unless insale

    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "insales"],
      target: dom_id(insale, :sync_section),
      partial: "insales/sync_section",
      locals: { insale: insale, loading: false }
    )
  end
end
