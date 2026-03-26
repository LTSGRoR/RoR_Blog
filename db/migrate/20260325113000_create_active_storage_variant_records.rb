class CreateActiveStorageVariantRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :active_storage_variant_records do |t|
      t.bigint :blob_id, null: false
      t.string :variation_digest, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :active_storage_variant_records, %i[blob_id variation_digest], name: "index_active_storage_variant_records_uniqueness", unique: true
  end
end
