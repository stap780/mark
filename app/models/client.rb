class Client < ApplicationRecord
  include ActionView::RecordIdentifier
  include Varbindable

  belongs_to :account

      # Varbindable implementation
      def show_path
        Rails.application.routes.url_helpers.account_client_path(
          account, self
        )
      end

      def varbinds_path
        Rails.application.routes.url_helpers.account_client_varbinds_path(
          account, self
        )
      end

      def varbind_new_path
        Rails.application.routes.url_helpers.new_account_client_varbind_path(
          account, self
        )
      end

      def varbind_edit_path(varbind)
        Rails.application.routes.url_helpers.edit_account_client_varbind_path(
          account, self, varbind
        )
      end

  def varbind_path(varbind)
    Rails.application.routes.url_helpers.account_client_varbind_path(
      account, self, varbind
    )
  end

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
    broadcast_prepend_to [account, :clients],
                        target: [account, :clients],
                        partial: "clients/client",
                        locals: { client: self }
  end

  after_update_commit do
    broadcast_replace_to [account, :clients],
                        target: dom_id(self),
                        partial: "clients/client",
                        locals: { client: self }
  end

  after_destroy_commit do
    broadcast_remove_to [account, :clients], target: dom_id(self)
  end
end
