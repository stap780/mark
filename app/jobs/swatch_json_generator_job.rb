class SwatchJsonGeneratorJob < ApplicationJob
  queue_as :swatch_json_generator

  def perform(account_id)
    SwatchJsonGenerator.new(account_id).call
  end
end
