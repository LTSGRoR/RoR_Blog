class AddServiceNameToActiveStorageBlobs < ActiveRecord::Migration[8.0]
  def change
    add_column :active_storage_blobs, :service_name, :string
    add_index :active_storage_blobs, :service_name
  end
end
