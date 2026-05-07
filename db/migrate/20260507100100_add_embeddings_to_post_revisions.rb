class AddEmbeddingsToPostRevisions < ActiveRecord::Migration[8.0]
  def change
    # Use explicit vector dimensionality so pgvector can build HNSW indexes.
    add_column :post_revisions, :embedding, "vector(768)"
    add_column :post_revisions, :embedding_generated_at, :datetime
    add_column :post_revisions, :feedback_suggestions, :jsonb
    add_column :post_revisions, :suggestions_generated_at, :datetime
    add_column :post_revisions, :suggestions_error, :boolean, default: false

    add_index :post_revisions, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
