class WebformJsonGeneratorJob < ApplicationJob
  queue_as :webform_json_generator

  def perform(account_id)
    WebformJsonGeneratorService.new(account_id).call
  end
end

