class WebformField < ApplicationRecord
  include WebformSettings
  include ActionView::RecordIdentifier
  belongs_to :webform
  has_one_attached :image

  acts_as_list scope: :webform_id, column: :position

  validates :name, :label, :field_type, presence: true
  validates :name, uniqueness: { scope: :webform_id }

  FIELD_TYPES = [
    ['text','text'],
    ['email','email'],
    ['textarea','textarea'],
    ['phone','phone'],
    ['number','number'],
    ['select','select'],
    ['checkbox','checkbox'],
    ['button','button'],
    ['image','image']
  ]
end


