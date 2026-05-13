class AddAiReviewFieldsToPostsAndPostRevisions < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :ai_review_status, :integer, null: false, default: 0
    add_column :posts, :ai_confidence, :float
    add_column :posts, :ai_risk_score, :float
    add_column :posts, :ai_provider, :string
    add_column :posts, :ai_model_name, :string
    add_column :posts, :ai_attempts_count, :integer, null: false, default: 0
    add_column :posts, :ai_last_error, :text
    add_column :posts, :ai_reviewed_at, :datetime
    add_column :posts, :ai_decision_payload, :jsonb, null: false, default: {}

    add_index :posts, :ai_review_status

    add_column :post_revisions, :ai_review_status, :integer, null: false, default: 0
    add_column :post_revisions, :ai_confidence, :float
    add_column :post_revisions, :ai_risk_score, :float
    add_column :post_revisions, :ai_provider, :string
    add_column :post_revisions, :ai_model_name, :string
    add_column :post_revisions, :ai_attempts_count, :integer, null: false, default: 0
    add_column :post_revisions, :ai_last_error, :text
    add_column :post_revisions, :ai_reviewed_at, :datetime
    add_column :post_revisions, :ai_decision_payload, :jsonb, null: false, default: {}

    add_index :post_revisions, :ai_review_status
  end
end
