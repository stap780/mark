class InsaleOrderImportJob < ApplicationJob
  queue_as :default

  def perform(payload)
    # TODO: Implement import logic akin to dizauto's Insale::OrderImport service
    Rails.logger.info("InsaleOrderImportJob received payload: #{payload.inspect}")
  end
end
