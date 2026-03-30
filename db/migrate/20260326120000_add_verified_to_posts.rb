class AddVerifiedToPosts < ActiveRecord::Migration[7.0]
  def change
    add_column :posts, :verified, :boolean, default: false, null: false
    add_column :posts, :verified_at, :datetime
    add_column :posts, :verified_by_id, :integer
    add_index :posts, :verified
  end
end
