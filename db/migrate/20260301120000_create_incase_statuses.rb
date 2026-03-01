# frozen_string_literal: true

class CreateIncaseStatuses < ActiveRecord::Migration[7.1]
  def up
    create_table :incase_statuses do |t|
      t.references :account, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.string :color, null: false, default: "bg-gray-100 text-gray-800"
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :incase_statuses, [:account_id, :key], unique: true

    # Create default statuses for all existing accounts (use raw SQL - model not yet loaded)
    default_statuses = [
      ["new", "Новая", "bg-blue-100 text-blue-800", 1],
      ["in_progress", "В работе", "bg-yellow-100 text-yellow-800", 2],
      ["done", "Выполнена", "bg-green-100 text-green-800", 3],
      ["canceled", "Отменена", "bg-red-100 text-red-800", 4],
      ["closed", "Закрыта", "bg-gray-100 text-gray-800", 5]
    ]
    conn = connection
    Account.find_each do |account|
      default_statuses.each_with_index do |(key, name, color, pos), i|
        execute <<-SQL.squish
          INSERT INTO incase_statuses (account_id, key, name, color, position, created_at, updated_at)
          VALUES (#{account.id}, #{conn.quote(key)}, #{conn.quote(name)}, #{conn.quote(color)}, #{pos + i}, NOW(), NOW())
        SQL
      end
    end

    # Add incase_status_id to incases and migrate data
    add_reference :incases, :incase_status, foreign_key: true

    # Migrate existing status strings to incase_status_id
    execute <<-SQL.squish
      UPDATE incases i
      SET incase_status_id = (
        SELECT id FROM incase_statuses s
        WHERE s.account_id = i.account_id AND s.key = i.status
        LIMIT 1
      )
    SQL

    # Set default for any null (e.g. invalid status)
    execute <<-SQL.squish
      UPDATE incases i
      SET incase_status_id = (
        SELECT id FROM incase_statuses s
        WHERE s.account_id = i.account_id AND s.key = 'new'
        LIMIT 1
      )
      WHERE incase_status_id IS NULL
    SQL

    remove_column :incases, :status
    change_column_null :incases, :incase_status_id, false
  end

  def down
    add_column :incases, :status, :string

    execute <<-SQL.squish
      UPDATE incases i
      SET status = (
        SELECT key FROM incase_statuses s WHERE s.id = i.incase_status_id LIMIT 1
      )
    SQL

    remove_reference :incases, :incase_status, foreign_key: true
    drop_table :incase_statuses
  end
end
