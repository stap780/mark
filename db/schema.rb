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

ActiveRecord::Schema[8.0].define(version: 2025_10_10_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.index ["admin"], name: "index_accounts_on_admin"
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

  create_table "clients", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name"
    t.string "surname"
    t.string "email"
    t.string "phone"
    t.string "ya_client"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_clients_on_account_id"
  end

  create_table "insales", force: :cascade do |t|
    t.string "api_key"
    t.string "api_password"
    t.string "api_link"
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "product_xml"
    t.index ["account_id"], name: "index_insales_on_account_id", unique: true
  end

  create_table "list_items", force: :cascade do |t|
    t.bigint "list_id", null: false
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "client_id", null: false
    t.index ["client_id"], name: "index_list_items_on_client_id"
    t.index ["item_type", "item_id"], name: "index_list_items_on_item"
    t.index ["list_id", "client_id", "item_type", "item_id"], name: "index_list_items_on_list_client_and_item", unique: true
    t.index ["list_id"], name: "index_list_items_on_list_id"
  end

  create_table "lists", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name"
    t.integer "items_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "icon_style", default: "icon_one", null: false
    t.string "icon_color", default: "#999999", null: false
    t.index ["account_id"], name: "index_lists_on_account_id"
    t.index ["icon_style"], name: "index_lists_on_icon_style"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_products_on_account_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "swatch_group_products", force: :cascade do |t|
    t.bigint "swatch_group_id", null: false
    t.bigint "product_id"
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
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "option_name", null: false
    t.integer "status", default: 0
    t.string "product_page_style", default: "circular_small_desktop"
    t.string "collection_page_style", default: "circular_small_mobile"
    t.string "swatch_image_source", default: "first_product_image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "css_class_product"
    t.string "css_class_preview"
    t.index ["account_id"], name: "index_swatch_groups_on_account_id"
    t.index ["name"], name: "index_swatch_groups_on_name"
    t.index ["status"], name: "index_swatch_groups_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.string "role", default: "member", null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "varbinds", force: :cascade do |t|
    t.string "varbindable_type", null: false
    t.bigint "varbindable_id", null: false
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
    t.bigint "product_id", null: false
    t.string "barcode"
    t.string "sku"
    t.decimal "price", precision: 12, scale: 2
    t.string "image_link"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["barcode"], name: "index_variants_on_barcode"
    t.index ["product_id"], name: "index_variants_on_product_id"
    t.index ["sku"], name: "index_variants_on_sku"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "clients", "accounts"
  add_foreign_key "insales", "accounts"
  add_foreign_key "list_items", "clients"
  add_foreign_key "list_items", "lists"
  add_foreign_key "lists", "accounts"
  add_foreign_key "products", "accounts"
  add_foreign_key "sessions", "users"
  add_foreign_key "swatch_group_products", "products"
  add_foreign_key "swatch_group_products", "swatch_groups"
  add_foreign_key "swatch_groups", "accounts"
  add_foreign_key "users", "accounts"
  add_foreign_key "variants", "products"
end
