class AddCommentsCountToPosts < ActiveRecord::Migration[8.0]
  # Counter cache for `post.comments.size`, which the public feed, the author
  # dashboard and the "most read" sidebar all render. Without the cache each
  # page load either loaded every comment row of every listed post or ran one
  # COUNT(*) per post.
  def up
    unless column_exists?(:posts, :comments_count)
      add_column :posts, :comments_count, :integer, default: 0, null: false
    end

    execute <<~SQL.squish
      UPDATE posts
         SET comments_count = comment_totals.total
        FROM (
          SELECT post_id, COUNT(*) AS total
            FROM comments
           GROUP BY post_id
        ) AS comment_totals
       WHERE posts.id = comment_totals.post_id
    SQL
  end

  def down
    remove_column :posts, :comments_count if column_exists?(:posts, :comments_count)
  end
end
