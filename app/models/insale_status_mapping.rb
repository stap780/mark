# frozen_string_literal: true

class InsaleStatusMapping < ApplicationRecord
  belongs_to :insale
  belongs_to :incase_status

  validates :insales_custom_status_permalink, presence: true
  validates :insales_financial_status, presence: true
  validates :insales_custom_status_permalink,
            uniqueness: { scope: [:insale_id, :insales_financial_status] }

  FINANCIAL_STATUSES = %w[pending paid].freeze
end
