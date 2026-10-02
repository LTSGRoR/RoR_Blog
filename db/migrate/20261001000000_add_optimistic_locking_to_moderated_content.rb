class AddOptimisticLockingToModeratedContent < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :lock_version, :integer, null: false, default: 0
    add_column :post_revisions, :lock_version, :integer, null: false, default: 0
    add_column :posts, :ai_review_token, :string
    add_column :post_revisions, :ai_review_token, :string
    add_index :chat_histories, :created_at
  end
end
