# frozen_string_literal: true

class SetCampaignsWebformIdNotNull < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE campaigns AS c
      SET webform_id = w.id
      FROM (
        SELECT DISTINCT ON (account_id) id, account_id
        FROM webforms
        ORDER BY account_id, id ASC
      ) AS w
      WHERE c.account_id = w.account_id
        AND c.webform_id IS NULL
    SQL

    execute "DELETE FROM campaigns WHERE webform_id IS NULL"

    change_column_null :campaigns, :webform_id, false
  end

  def down
    change_column_null :campaigns, :webform_id, true
  end
end
