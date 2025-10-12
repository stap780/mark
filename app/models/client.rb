class Client < ApplicationRecord
  include ActionView::RecordIdentifier
  include Varbindable
  include AccountScoped

  belongs_to :account
  has_many :list_items, dependent: :destroy
  has_one_attached :list_items_file

  validates :name, presence: true

  # Use Varbindable defaults

  def broadcast_target_for_varbinds
    [account, [self, :varbinds]]
  end

  def broadcast_target_id_for_varbinds
    dom_id(account, dom_id(self, :varbinds))
  end

  def broadcast_locals_for_varbind(varbind)
    { client: self, varbind: varbind }
  end

  # Hotwire broadcasts
  after_create_commit do
    broadcast_prepend_to [self.account, :clients],
                        target: [self.account, :clients],
                        partial: "clients/client",
                        locals: { client: self, current_account: self.account }
  end

  after_update_commit do
    broadcast_replace_to [self.account, :clients],
                        target: dom_id(self),
                        partial: "clients/client",
                        locals: { client: self, current_account: self.account }
  end

  after_destroy_commit do
    broadcast_remove_to [self.account, :clients], target: dom_id(self)
  end


  def self.ransackable_attributes(auth_object = nil)
    Client.attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[list_items]
  end



end
