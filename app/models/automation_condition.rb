class AutomationCondition < ApplicationRecord
  belongs_to :automation_rule
  
  validates :field, :operator, presence: true
  
  scope :ordered, -> { order(:position, :id) }
end

