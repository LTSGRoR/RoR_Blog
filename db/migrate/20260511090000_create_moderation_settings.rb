class CreateModerationSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :moderation_settings do |t|
      t.string :provider, null: false, default: "ollama"
      t.string :ai_model, null: false, default: "gemma4:latest"
      t.float :auto_approve_threshold, null: false, default: 0.9
      t.integer :request_timeout_seconds, null: false, default: 30
      t.integer :max_retries, null: false, default: 3
      t.boolean :auto_review_enabled, null: false, default: true
      t.text :new_post_instruction, null: false
      t.text :revision_instruction, null: false

      t.timestamps
    end
  end
end
