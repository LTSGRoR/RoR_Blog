# Solid Cache backs Rails.cache (config.cache_store = :solid_cache_store in
# production). The cache/queue/cable adapters run against the primary database
# here (config/database.yml points them at DATABASE_URL), and `db:prepare` only
# loads db/cache_schema.rb when it creates a *separate* cache database, so
# without this migration `Rails.cache` fails with
# "No unique index found for key_hash" on a missing solid_cache_entries table.
# Contents mirror db/cache_schema.rb, as documented for single-database setups.
class CreateSolidCacheTables < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_cache_entries, if_not_exists: true do |t|
      t.binary "key", limit: 1024, null: false
      t.binary "value", limit: 536870912, null: false
      t.datetime "created_at", null: false
      t.integer "key_hash", limit: 8, null: false
      t.integer "byte_size", limit: 4, null: false

      t.index [ "byte_size" ], name: "index_solid_cache_entries_on_byte_size"
      t.index [ "key_hash", "byte_size" ], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
      t.index [ "key_hash" ], name: "index_solid_cache_entries_on_key_hash", unique: true
    end
  end
end
