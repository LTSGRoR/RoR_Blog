class EnablePgvectorExtension < ActiveRecord::Migration[8.0]
  def up
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    # Ensure the current AR connection learns about the new vector type
    # so follow-up migrations in the same run do not warn about unknown OIDs.
    connection.send(:reload_type_map) if connection.respond_to?(:reload_type_map, true)
  end

  def down
    execute "DROP EXTENSION IF EXISTS vector"
  end
end
