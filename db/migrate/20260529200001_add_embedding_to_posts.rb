class AddEmbeddingToPosts < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'vector' unless extension_enabled?('vector')

    # Ensure the column is created with explicit dimensions (pgvector requires dimensions)
    unless column_exists?(:posts, :embedding)
      execute <<~SQL
        ALTER TABLE posts
        ADD COLUMN embedding vector(1536);
      SQL
    end

    # Create ivfflat index (specify lists option). Guard with IF NOT EXISTS.
    execute <<~SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE c.relname = 'index_posts_on_embedding') THEN
          CREATE INDEX index_posts_on_embedding ON posts USING ivfflat (embedding) WITH (lists = 100);
        END IF;
      END$$;
    SQL
  end
end
