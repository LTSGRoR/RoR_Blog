class AddEmbeddingToChatHistories < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:chat_histories, :embedding)
      execute <<~SQL
        ALTER TABLE chat_histories
        ADD COLUMN embedding vector(1536);
      SQL
    end

    unless index_exists?(:chat_histories, :embedding)
      execute <<~SQL
        CREATE INDEX index_chat_histories_on_embedding ON chat_histories USING ivfflat (embedding) WITH (lists = 100);
      SQL
    end
  end

  def down
    if index_exists?(:chat_histories, :embedding)
      remove_index :chat_histories, :embedding
    end

    if column_exists?(:chat_histories, :embedding)
      remove_column :chat_histories, :embedding
    end
  end
end