class Inswatch < ApplicationRecord
  belongs_to :user

  validates :uid, presence: true, uniqueness: true
  validates :user_id, presence: true

  scope :installed, -> { where(installed: true) }
  
  def installed?
    installed == true
  end
end

