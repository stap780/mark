class CreateMessageTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :message_templates do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title, null: false
      t.string :channel, null: false
      t.string :subject
      t.text :content, null: false
      t.string :context

      t.timestamps
    end
  end
end

