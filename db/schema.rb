# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_22_160705) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_users", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "account_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_users_on_account_id"
    t.index ["role"], name: "index_account_users_on_role"
    t.index ["user_id", "account_id"], name: "index_account_users_on_user_id_and_account_id", unique: true
    t.index ["user_id"], name: "index_account_users_on_user_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.boolean "partner", default: false, null: false
    t.jsonb "settings", default: {}
    t.index ["admin"], name: "index_accounts_on_admin"
    t.index ["partner"], name: "index_accounts_on_partner"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "automation_actions", force: :cascade do |t|
    t.bigint "automation_rule_id", null: false
    t.string "kind", null: false
    t.jsonb "settings"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["automation_rule_id"], name: "index_automation_actions_on_automation_rule_id"
  end

  create_table "automation_conditions", force: :cascade do |t|
    t.bigint "automation_rule_id", null: false
    t.string "field", null: false
    t.string "operator", null: false
    t.string "value"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["automation_rule_id", "position"], name: "index_automation_conditions_on_automation_rule_id_and_position"
    t.index ["automation_rule_id"], name: "index_automation_conditions_on_automation_rule_id"
  end

  create_table "automation_messages", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "automation_rule_id", null: false
    t.bigint "automation_action_id", null: false
    t.bigint "client_id", null: false
    t.bigint "incase_id"
    t.string "channel", null: false
    t.string "status", default: "pending"
    t.text "subject"
    t.text "content"
    t.text "error_message"
    t.datetime "sent_at"
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "message_id"
    t.string "x_track_id"
    t.index ["account_id", "channel", "status"], name: "index_automation_messages_on_account_id_and_channel_and_status"
    t.index ["account_id"], name: "index_automation_messages_on_account_id"
    t.index ["automation_action_id"], name: "index_automation_messages_on_automation_action_id"
    t.index ["automation_rule_id", "created_at"], name: "index_automation_messages_on_automation_rule_id_and_created_at"
    t.index ["automation_rule_id"], name: "index_automation_messages_on_automation_rule_id"
    t.index ["client_id"], name: "index_automation_messages_on_client_id"
    t.index ["incase_id"], name: "index_automation_messages_on_incase_id"
    t.index ["message_id"], name: "index_automation_messages_on_message_id"
    t.index ["x_track_id"], name: "index_automation_messages_on_x_track_id"
  end

  create_table "automation_rules", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "title", null: false
    t.string "event", null: false
    t.string "condition_type", default: "simple"
    t.text "condition"
    t.boolean "active", default: true
    t.integer "position"
    t.integer "delay_seconds", default: 0
    t.datetime "scheduled_for"
    t.string "active_job_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "logic_operator", default: "AND"
    t.index ["account_id"], name: "index_automation_rules_on_account_id"
    t.index ["active_job_id"], name: "index_automation_rules_on_active_job_id"
    t.index ["scheduled_for"], name: "index_automation_rules_on_scheduled_for"
  end

  create_table "clients", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "name"
    t.string "surname"
    t.string "email"
    t.string "phone"
    t.string "ya_client"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_clients_on_account_id"
  end

  create_table "discounts", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "title"
    t.string "rule"
    t.string "move"
    t.string "shift"
    t.string "points"
    t.string "notice"
    t.integer "position", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_discounts_on_account_id"
  end

  create_table "email_setups", force: :cascade do |t|
    t.string "address"
    t.integer "port"
    t.string "domain"
    t.string "authentication"
    t.string "user_name"
    t.string "user_password"
    t.boolean "tls", default: true
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_email_setups_on_account_id"
  end

  create_table "incases", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "status", default: "new", null: false
    t.integer "webform_id", null: false
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "number"
    t.integer "display_number"
    t.jsonb "custom_fields", default: {}
    t.index ["account_id", "created_at"], name: "index_incases_on_account_id_and_created_at"
    t.index ["account_id", "display_number"], name: "index_incases_on_account_id_and_display_number", unique: true, where: "(display_number IS NOT NULL)"
    t.index ["account_id", "number"], name: "index_incases_on_account_id_and_number", unique: true, where: "(number IS NOT NULL)"
    t.index ["account_id", "status"], name: "index_incases_on_account_id_and_status"
    t.index ["account_id"], name: "index_incases_on_account_id"
    t.index ["client_id"], name: "index_incases_on_client_id"
    t.index ["custom_fields"], name: "index_incases_on_custom_fields", using: :gin
    t.index ["webform_id"], name: "index_incases_on_webform_id"
  end

  create_table "insales", force: :cascade do |t|
    t.string "api_key"
    t.string "api_password"
    t.string "api_link"
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "product_xml"
    t.index ["account_id"], name: "index_insales_on_account_id", unique: true
  end

  create_table "inswatches", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "uid", null: false
    t.string "shop"
    t.boolean "installed", default: false, null: false
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop"], name: "index_inswatches_on_shop"
    t.index ["uid"], name: "index_inswatches_on_uid", unique: true
    t.index ["user_id"], name: "index_inswatches_on_user_id"
  end

  create_table "items", force: :cascade do |t|
    t.integer "incase_id", null: false
    t.integer "quantity"
    t.decimal "price", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_id", null: false
    t.bigint "variant_id", null: false
    t.index ["incase_id"], name: "index_items_on_incase_id"
    t.index ["product_id"], name: "index_items_on_product_id"
    t.index ["variant_id"], name: "index_items_on_variant_id"
  end

  create_table "list_items", force: :cascade do |t|
    t.integer "list_id", null: false
    t.string "item_type", null: false
    t.integer "item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "client_id", null: false
    t.index ["client_id"], name: "index_list_items_on_client_id"
    t.index ["item_type", "item_id"], name: "index_list_items_on_item"
    t.index ["list_id", "client_id", "item_type", "item_id"], name: "index_list_items_on_list_client_and_item", unique: true
    t.index ["list_id"], name: "index_list_items_on_list_id"
  end

  create_table "lists", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "name"
    t.integer "items_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "icon_style", default: "icon_one", null: false
    t.string "icon_color", default: "#999999", null: false
    t.index ["account_id"], name: "index_lists_on_account_id"
    t.index ["icon_style"], name: "index_lists_on_icon_style"
  end

  create_table "mailganers", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "api_key", null: false
    t.string "smtp_login", null: false
    t.string "api_key_web_portal", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "from_email"
    t.string "test_subject"
    t.index ["account_id"], name: "index_mailganers_on_account_id"
  end

  create_table "message_templates", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "title", null: false
    t.string "channel", null: false
    t.string "subject"
    t.text "content", null: false
    t.string "context"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_message_templates_on_account_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "subscription_id", null: false
    t.integer "amount", null: false
    t.string "status", null: false
    t.datetime "paid_at"
    t.string "processor", null: false
    t.jsonb "processor_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["processor"], name: "index_payments_on_processor"
    t.index ["status"], name: "index_payments_on_status"
    t.index ["subscription_id"], name: "index_payments_on_subscription_id"
  end

  create_table "plans", force: :cascade do |t|
    t.string "name", null: false
    t.integer "price", null: false
    t.string "interval", null: false
    t.boolean "active", default: true, null: false
    t.integer "trial_days", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_plans_on_active"
    t.index ["name"], name: "index_plans_on_name", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_products_on_account_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stock_check_schedules", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "active", default: false
    t.string "time"
    t.string "recurrence"
    t.datetime "scheduled_for"
    t.string "active_job_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_stock_check_schedules_on_account_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "plan_id", null: false
    t.string "status", null: false
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_subscriptions_on_account_id"
    t.index ["plan_id"], name: "index_subscriptions_on_plan_id"
    t.index ["status"], name: "index_subscriptions_on_status"
  end

  create_table "swatch_group_products", force: :cascade do |t|
    t.integer "swatch_group_id", null: false
    t.integer "product_id"
    t.string "swatch_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "color"
    t.string "title"
    t.string "image_link"
    t.string "swatch_label"
    t.index ["product_id"], name: "index_swatch_group_products_on_product_id"
    t.index ["swatch_group_id", "product_id"], name: "index_sgp_on_group_and_product", unique: true
    t.index ["swatch_group_id"], name: "index_swatch_group_products_on_swatch_group_id"
  end

  create_table "swatch_groups", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "name", null: false
    t.string "option_name", null: false
    t.integer "status", default: 0
    t.string "product_page_style", default: "circular_small_desktop"
    t.string "collection_page_style", default: "circular_small_mobile"
    t.string "product_page_image_source", default: "first_product_image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "css_class_product"
    t.string "css_class_preview"
    t.string "product_page_style_mob"
    t.string "collection_page_style_mob"
    t.string "collection_page_image_source", default: "first_product_image"
    t.index ["account_id"], name: "index_swatch_groups_on_account_id"
    t.index ["name"], name: "index_swatch_groups_on_name"
    t.index ["status"], name: "index_swatch_groups_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "varbinds", force: :cascade do |t|
    t.string "varbindable_type", null: false
    t.integer "varbindable_id", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.index ["record_type", "record_id"], name: "index_varbinds_on_record_type_and_record_id"
    t.index ["value"], name: "index_varbinds_on_value"
    t.index ["varbindable_type", "varbindable_id", "record_type", "record_id", "value"], name: "index_varbinds_on_varbindable_record_and_value", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "barcode"
    t.string "sku"
    t.decimal "price", precision: 12, scale: 2
    t.string "image_link"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "quantity", default: 0, null: false
    t.index ["barcode"], name: "index_variants_on_barcode"
    t.index ["product_id"], name: "index_variants_on_product_id"
    t.index ["sku"], name: "index_variants_on_sku"
  end

  create_table "webform_fields", force: :cascade do |t|
    t.integer "webform_id", null: false
    t.string "name", null: false
    t.string "label", null: false
    t.string "field_type", null: false
    t.boolean "required", default: false, null: false
    t.jsonb "settings"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["webform_id", "name"], name: "index_webform_fields_on_webform_id_and_name", unique: true
    t.index ["webform_id"], name: "index_webform_fields_on_webform_id"
  end

  create_table "webforms", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "title", null: false
    t.string "kind", null: false
    t.string "status", default: "inactive", null: false
    t.jsonb "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "kind", "status"], name: "index_webforms_on_account_id_and_kind_and_status"
    t.index ["account_id", "kind"], name: "index_webforms_on_account_kind_singleton", unique: true, where: "((kind)::text = ANY ((ARRAY['order'::character varying, 'notify'::character varying, 'preorder'::character varying, 'abandoned_cart'::character varying])::text[]))"
    t.index ["account_id"], name: "index_webforms_on_account_id"
  end

  add_foreign_key "account_users", "accounts"
  add_foreign_key "account_users", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "automation_actions", "automation_rules"
  add_foreign_key "automation_conditions", "automation_rules"
  add_foreign_key "automation_messages", "accounts"
  add_foreign_key "automation_messages", "automation_actions"
  add_foreign_key "automation_messages", "automation_rules"
  add_foreign_key "automation_messages", "clients"
  add_foreign_key "automation_messages", "incases"
  add_foreign_key "automation_rules", "accounts"
  add_foreign_key "clients", "accounts"
  add_foreign_key "discounts", "accounts"
  add_foreign_key "email_setups", "accounts"
  add_foreign_key "incases", "accounts"
  add_foreign_key "incases", "clients"
  add_foreign_key "incases", "webforms"
  add_foreign_key "insales", "accounts"
  add_foreign_key "inswatches", "users"
  add_foreign_key "items", "incases"
  add_foreign_key "items", "products"
  add_foreign_key "items", "variants"
  add_foreign_key "list_items", "clients"
  add_foreign_key "list_items", "lists"
  add_foreign_key "lists", "accounts"
  add_foreign_key "mailganers", "accounts"
  add_foreign_key "message_templates", "accounts"
  add_foreign_key "payments", "subscriptions"
  add_foreign_key "products", "accounts"
  add_foreign_key "sessions", "users"
  add_foreign_key "stock_check_schedules", "accounts"
  add_foreign_key "subscriptions", "accounts"
  add_foreign_key "subscriptions", "plans"
  add_foreign_key "swatch_group_products", "products"
  add_foreign_key "swatch_group_products", "swatch_groups"
  add_foreign_key "swatch_groups", "accounts"
  add_foreign_key "variants", "products"
  add_foreign_key "webform_fields", "webforms"
  add_foreign_key "webforms", "accounts"
end
