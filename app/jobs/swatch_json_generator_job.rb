class SwatchJsonGeneratorJob < ApplicationJob
  queue_as :swatch_json_generator

  def perform(account_id)
    SwatchJsonGeneratorService.new(account_id).call
  end
end
