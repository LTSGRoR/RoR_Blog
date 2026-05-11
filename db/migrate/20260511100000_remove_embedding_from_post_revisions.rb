class RemoveEmbeddingFromPostRevisions < ActiveRecord::Migration[8.0]
  def up
    if column_exists?(:post_revisions, :embedding)
      remove_column :post_revisions, :embedding
    end

    disable_extension "vector" if extension_enabled?("vector")
  end

  def down
    enable_extension "vector" unless extension_enabled?("vector")

    return if column_exists?(:post_revisions, :embedding)

    execute <<~SQL
      ALTER TABLE post_revisions
      ADD COLUMN embedding vector(768)
    SQL
  end
end
