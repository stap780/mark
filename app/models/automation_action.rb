class AutomationAction < ApplicationRecord
  belongs_to :automation_rule

  enum :kind, {
    send_email: 'send_email',
    change_status: 'change_status'
  }

  validates :kind, presence: true

  # Virtual attributes for form handling
  attr_accessor :template_id, :new_status

  before_save :build_settings_from_virtual_attributes

  def template_id
    @template_id || settings&.dig('template_id')
  end

  def new_status
    @new_status || settings&.dig('status')
  end

  private

  def build_settings_from_virtual_attributes
    self.settings ||= {}
    self.settings = {} if self.settings.blank?

    case kind
    when 'send_email'
      if @template_id.present?
        self.settings['template_id'] = @template_id.to_i
      else
        self.settings.delete('template_id')
      end
      self.settings.delete('status')
    when 'change_status'
      if @new_status.present?
        self.settings['status'] = @new_status
      else
        self.settings.delete('status')
      end
      self.settings.delete('template_id')
    end

    # Clean up empty settings hash
    self.settings = nil if self.settings.empty?
  end
end

