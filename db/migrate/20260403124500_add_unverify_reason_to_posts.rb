class AddUnverifyReasonToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :unverify_reason, :text
    add_column :posts, :reviewed_at, :datetime
    add_reference :posts, :reviewed_by, foreign_key: { to_table: :users }, type: :bigint
  end
end
