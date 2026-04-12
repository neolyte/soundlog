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

ActiveRecord::Schema[8.0].define(version: 2026_04_13_001000) do
  create_table "clients", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_clients_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "projects", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "user_id", null: false
    t.bigint "client_id", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "total_hours", precision: 8, scale: 2
    t.index ["client_id"], name: "index_projects_on_client_id"
    t.index ["user_id", "client_id"], name: "index_projects_on_user_id_and_client_id"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "time_entries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "project_id", null: false
    t.date "date", null: false
    t.decimal "hours", precision: 8, scale: 2, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "date"], name: "index_time_entries_on_project_id_and_date"
    t.index ["project_id"], name: "index_time_entries_on_project_id"
    t.index ["user_id", "date"], name: "index_time_entries_on_user_id_and_date"
    t.index ["user_id"], name: "index_time_entries_on_user_id"
  end

  create_table "timers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "project_id"
    t.text "description"
    t.string "state", default: "running", null: false
    t.datetime "started_at"
    t.integer "accumulated_seconds", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_timers_on_project_id"
    t.index ["user_id"], name: "index_timers_on_user_id", unique: true
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "clients", "users"
  add_foreign_key "projects", "clients"
  add_foreign_key "projects", "users"
  add_foreign_key "time_entries", "projects"
  add_foreign_key "time_entries", "users"
  add_foreign_key "timers", "projects"
  add_foreign_key "timers", "users"
end
