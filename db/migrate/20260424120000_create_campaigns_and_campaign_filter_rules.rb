# frozen_string_literal: true

class CreateCampaignsAndCampaignFilterRules < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title, null: false
      t.references :webform, null: true, foreign_key: true
      t.string :time
      t.string :recurrence, default: "daily"
      t.boolean :recurring, null: false, default: true
      t.boolean :active, null: false, default: false
      t.datetime :scheduled_for
      t.string :active_job_id
      t.datetime :last_run_at
      t.integer :dedupe_days, null: false, default: 35
      t.text :notes
      t.timestamps
    end

    add_index :campaigns, %i[account_id active]

    create_table :campaign_filter_rules do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false, default: 0
      t.string :target, null: false, default: "incase"
      t.string :field, null: false
      t.string :operator, null: false, default: "equals"
      t.text :value
      t.timestamps
    end

    add_index :campaign_filter_rules, %i[campaign_id position]

    add_reference :incases, :campaign, null: true, foreign_key: true
  end
end
