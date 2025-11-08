module Billing
  class << self
    attr_accessor :config
  end

  def self.configure
    self.config ||= Configuration.new
    yield(config) if block_given?
    config
  end

  class Configuration
    attr_accessor :providers

    def initialize
      @providers = {
        paymaster: {
          merchant_id: Rails.application.credentials.dig(:paymaster, :merchant_id),
          secret: Rails.application.credentials.dig(:paymaster, :secret),
          base_url: Rails.application.credentials.dig(:paymaster, :base_url) || "https://paymaster.ru",
          success_url: Rails.application.credentials.dig(:paymaster, :success_url),
          fail_url: Rails.application.credentials.dig(:paymaster, :fail_url),
          result_url: Rails.application.credentials.dig(:paymaster, :result_url)
        },
        invoice: {
          # Настройки для счетов
        },
        cash: {
          # Настройки для наличных
        }
      }
    end
  end
end

Billing.configure

