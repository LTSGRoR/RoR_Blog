class AddEmbeddingSourceDigestToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :embedding_source_digest, :string unless column_exists?(:posts, :embedding_source_digest)
  end
end