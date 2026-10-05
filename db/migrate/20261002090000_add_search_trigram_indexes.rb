class AddSearchTrigramIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")
    %w[posts post_revisions].each do |table|
      add_index table, :title, using: :gin, opclass: :gin_trgm_ops, algorithm: :concurrently
    end
    %w[name email].each do |column|
      add_index :users, column, using: :gin, opclass: :gin_trgm_ops,
        name: "index_users_on_#{column}_trigram", algorithm: :concurrently
    end
    add_index :tags, :name, using: :gin, opclass: :gin_trgm_ops,
      name: "index_tags_on_name_trigram", algorithm: :concurrently
    execute "CREATE INDEX CONCURRENTLY index_tags_on_normalized_name_trigram ON tags USING gin ((regexp_replace(name, '[[:space:]-]+', ' ', 'g')) gin_trgm_ops)"
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_tags_on_normalized_name_trigram"
    remove_index :tags, name: "index_tags_on_name_trigram", algorithm: :concurrently
    %w[name email].each do |column|
      remove_index :users, name: "index_users_on_#{column}_trigram", algorithm: :concurrently
    end
    %w[posts post_revisions].each do |table|
      remove_index table, :title, algorithm: :concurrently
    end
  end
end
