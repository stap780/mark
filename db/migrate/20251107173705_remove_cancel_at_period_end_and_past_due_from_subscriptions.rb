class RemoveCancelAtPeriodEndAndPastDueFromSubscriptions < ActiveRecord::Migration[8.0]
  def change
    remove_column :subscriptions, :cancel_at_period_end, :boolean, default: false, null: false
  end
end
