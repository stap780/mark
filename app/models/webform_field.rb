class WebformField < ApplicationRecord
  include WebformSettings
  include ActionView::RecordIdentifier
  belongs_to :webform

  acts_as_list scope: :webform_id, column: :position

  validates :name, :label, :field_type, presence: true
  validates :name, uniqueness: { scope: :webform_id }

  # after_create_commit do
  #   broadcast_append_to dom_id(webform.account, dom_id(webform, :webform_fields)),
  #                       target: dom_id(webform.account, dom_id(webform, :webform_fields)),
  #                       partial: "webform_fields/webform_field",
  #                       locals: { webform: webform, field: self, current_account: webform.account }
  # end

  # after_update_commit do
  #   broadcast_replace_to dom_id(webform.account, dom_id(webform, :webform_fields)),
  #                       target: dom_id(webform.account, dom_id(self)),
  #                       partial: "webform_fields/webform_field",
  #                       locals: { webform: webform, field: self, current_account: webform.account }
  # end

  # after_destroy_commit do
  #   broadcast_remove_to dom_id(webform.account, dom_id(webform, :webform_fields)), target: dom_id(webform.account, dom_id(self))
  # end

end


