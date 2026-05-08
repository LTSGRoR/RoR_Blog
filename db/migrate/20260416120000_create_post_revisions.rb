class CreatePostRevisions < ActiveRecord::Migration[8.0]
  def change
    create_table :post_revisions do |t|
      t.references :post, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :reviewer, foreign_key: { to_table: :users }
      t.integer :moderation_status, null: false, default: 0
      t.string :title, null: false
      t.text :review_note
      t.datetime :submitted_at
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :post_revisions, :moderation_status
    add_index :post_revisions,
              %i[post_id moderation_status],
              unique: true,
              where: "moderation_status IN (0, 1)",
              name: "index_post_revisions_on_post_id_and_open_status"
  end
end
