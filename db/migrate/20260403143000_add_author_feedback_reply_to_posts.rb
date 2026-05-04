class AddAuthorFeedbackReplyToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :author_feedback_reply, :text
    add_column :posts, :author_replied_at, :datetime
  end
end
