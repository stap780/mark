class ProductInsaleSyncJob < ApplicationJob
  queue_as :product_insale_sync

  def perform(account_id, product_id)
    Account.switch_to(account_id)
    product = Product.find_by(id: product_id)
    return unless product

    ok, msg = product.insale_api_update
    Rails.logger.info("ProductInsaleSyncJob result: #{ok ? 'ok' : 'fail'} #{msg.inspect}")
  end

end