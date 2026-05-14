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

ActiveRecord::Schema[8.0].define(version: 2026_05_14_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
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
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name"
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
    t.index ["service_name"], name: "index_active_storage_blobs_on_service_name"
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "moderation_settings", force: :cascade do |t|
    t.string "provider", default: "ollama", null: false
    t.string "ai_model", default: "gemma4:latest", null: false
    t.float "auto_approve_threshold", default: 0.9, null: false
    t.integer "request_timeout_seconds", default: 30, null: false
    t.integer "max_retries", default: 3, null: false
    t.boolean "auto_review_enabled", default: true, null: false
    t.text "new_post_instruction", null: false
    t.text "revision_instruction", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "api_key"
  end

  create_table "post_revision_taggings", force: :cascade do |t|
    t.bigint "post_revision_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_revision_id", "tag_id"], name: "index_post_revision_taggings_on_post_revision_id_and_tag_id", unique: true
    t.index ["post_revision_id"], name: "index_post_revision_taggings_on_post_revision_id"
    t.index ["tag_id"], name: "index_post_revision_taggings_on_tag_id"
  end

  create_table "post_revisions", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "author_id", null: false
    t.bigint "reviewer_id"
    t.integer "moderation_status", default: 0, null: false
    t.string "title", null: false
    t.text "review_note"
    t.datetime "submitted_at"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "embedding_generated_at"
    t.jsonb "feedback_suggestions"
    t.datetime "suggestions_generated_at"
    t.boolean "suggestions_error", default: false
    t.integer "ai_review_status", default: 0, null: false
    t.float "ai_confidence"
    t.float "ai_risk_score"
    t.string "ai_provider"
    t.string "ai_model_name"
    t.integer "ai_attempts_count", default: 0, null: false
    t.text "ai_last_error"
    t.datetime "ai_reviewed_at"
    t.jsonb "ai_decision_payload", default: {}, null: false
    t.index ["ai_review_status"], name: "index_post_revisions_on_ai_review_status"
    t.index ["author_id"], name: "index_post_revisions_on_author_id"
    t.index ["moderation_status"], name: "index_post_revisions_on_moderation_status"
    t.index ["post_id", "moderation_status"], name: "index_post_revisions_on_post_id_and_open_status", unique: true, where: "(moderation_status = ANY (ARRAY[0, 1]))"
    t.index ["post_id"], name: "index_post_revisions_on_post_id"
    t.index ["reviewer_id"], name: "index_post_revisions_on_reviewer_id"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title", null: false
    t.integer "status", default: 0, null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.datetime "verified_at"
    t.integer "verified_by_id"
    t.text "unverify_reason"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.text "author_feedback_reply"
    t.datetime "author_replied_at"
    t.integer "ai_review_status", default: 0, null: false
    t.float "ai_confidence"
    t.float "ai_risk_score"
    t.string "ai_provider"
    t.string "ai_model_name"
    t.integer "ai_attempts_count", default: 0, null: false
    t.text "ai_last_error"
    t.datetime "ai_reviewed_at"
    t.jsonb "ai_decision_payload", default: {}, null: false
    t.index ["ai_review_status"], name: "index_posts_on_ai_review_status"
    t.index ["reviewed_by_id"], name: "index_posts_on_reviewed_by_id"
    t.index ["status"], name: "index_posts_on_status"
    t.index ["user_id"], name: "index_posts_on_user_id"
    t.index ["verified"], name: "index_posts_on_verified"
  end

  create_table "reactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "reactable_type", null: false
    t.bigint "reactable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "emoji_type", null: false
    t.index ["reactable_type", "reactable_id"], name: "index_reactions_on_reactable"
    t.index ["user_id", "reactable_type", "reactable_id"], name: "index_reactions_unique_per_user_target", unique: true
    t.index ["user_id"], name: "index_reactions_on_user_id"
  end

  create_table "taggings", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id", "tag_id"], name: "index_taggings_on_post_id_and_tag_id", unique: true
    t.index ["post_id"], name: "index_taggings_on_post_id"
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "banned_at"
    t.datetime "suspended_until"
    t.string "suspended_time_zone"
    t.string "locale"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["locale"], name: "index_users_on_locale"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["suspended_time_zone"], name: "index_users_on_suspended_time_zone"
  end

  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "post_revision_taggings", "post_revisions"
  add_foreign_key "post_revision_taggings", "tags"
  add_foreign_key "post_revisions", "posts"
  add_foreign_key "post_revisions", "users", column: "author_id"
  add_foreign_key "post_revisions", "users", column: "reviewer_id"
  add_foreign_key "posts", "users"
  add_foreign_key "posts", "users", column: "reviewed_by_id"
  add_foreign_key "reactions", "users"
  add_foreign_key "taggings", "posts"
  add_foreign_key "taggings", "tags"
end
