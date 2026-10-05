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

ActiveRecord::Schema[8.1].define(version: 2026_10_05_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "vector"

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

  create_table "chat_daily_quotas", force: :cascade do |t|
    t.date "day", null: false
    t.integer "requests_count", default: 0, null: false
    t.index ["day"], name: "index_chat_daily_quotas_on_day", unique: true
  end

  create_table "chat_histories", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "post_id"
    t.text "user_message"
    t.text "bot_response"
    t.string "provider"
    t.jsonb "provider_meta", default: {}
    t.jsonb "meta", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.vector "embedding", limit: 1536
    t.datetime "cleared_at"
    t.index ["created_at"], name: "index_chat_histories_on_created_at"
    t.index ["embedding"], name: "index_chat_histories_on_embedding", using: :ivfflat
    t.index ["post_id"], name: "index_chat_histories_on_post_id"
    t.index ["user_id", "created_at"], name: "index_chat_histories_on_user_and_created_at"
    t.index ["user_id"], name: "index_chat_histories_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["post_id", "parent_id", "created_at"], name: "index_comments_on_post_and_parent_created"
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
    t.text "assistant_prompt"
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
    t.integer "ai_review_status", default: 0, null: false
    t.float "ai_confidence"
    t.float "ai_risk_score"
    t.string "ai_provider"
    t.string "ai_model_name"
    t.integer "ai_attempts_count", default: 0, null: false
    t.text "ai_last_error"
    t.datetime "ai_reviewed_at"
    t.jsonb "ai_decision_payload", default: {}, null: false
    t.integer "lock_version", default: 0, null: false
    t.string "ai_review_token"
    t.index ["ai_review_status"], name: "index_post_revisions_on_ai_review_status"
    t.index ["author_id"], name: "index_post_revisions_on_author_id"
    t.index ["moderation_status"], name: "index_post_revisions_on_moderation_status"
    t.index ["post_id", "moderation_status", "updated_at"], name: "index_post_revisions_on_post_and_status_updated"
    t.index ["post_id", "moderation_status"], name: "index_post_revisions_on_post_id_and_open_status", unique: true, where: "(moderation_status = ANY (ARRAY[0, 1]))"
    t.index ["post_id"], name: "index_post_revisions_on_post_id"
    t.index ["reviewer_id"], name: "index_post_revisions_on_reviewer_id"
    t.index ["title"], name: "index_post_revisions_on_title", opclass: :gin_trgm_ops, using: :gin
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
    t.vector "embedding", limit: 1536
    t.string "embedding_source_digest"
    t.integer "comments_count", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.string "ai_review_token"
    t.index ["ai_review_status"], name: "index_posts_on_ai_review_status"
    t.index ["embedding"], name: "index_posts_on_embedding", using: :ivfflat
    t.index ["reviewed_by_id"], name: "index_posts_on_reviewed_by_id"
    t.index ["status", "verified", "created_at"], name: "index_posts_on_feed_ordering"
    t.index ["status"], name: "index_posts_on_status"
    t.index ["title"], name: "index_posts_on_title", opclass: :gin_trgm_ops, using: :gin
    t.index ["user_id", "status", "verified"], name: "index_posts_on_owner_and_visibility"
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
    t.index ["reactable_type", "reactable_id", "emoji_type"], name: "index_reactions_on_reactable_and_emoji"
    t.index ["user_id", "reactable_type", "reactable_id"], name: "index_reactions_unique_per_user_target", unique: true
    t.index ["user_id"], name: "index_reactions_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
    t.index "regexp_replace((name)::text, '[[:space:]-]+'::text, ' '::text, 'g'::text) gin_trgm_ops", name: "index_tags_on_normalized_name_trigram", using: :gin
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["name"], name: "index_tags_on_name_trigram", opclass: :gin_trgm_ops, using: :gin
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
    t.string "profile_title"
    t.text "bio"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["email"], name: "index_users_on_email_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["locale"], name: "index_users_on_locale"
    t.index ["name"], name: "index_users_on_name_trigram", opclass: :gin_trgm_ops, using: :gin
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
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "taggings", "posts"
  add_foreign_key "taggings", "tags"
end
