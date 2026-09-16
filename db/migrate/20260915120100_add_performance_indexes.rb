class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  # Indexes for the hottest read paths:
  #   * public feed / landing / blog search fallback
  #       WHERE status = published AND verified ORDER BY created_at DESC
  #   * author dashboard + public profile per-owner listings/filters
  #   * comment trees (root comments of a post, replies of a comment)
  #   * reaction aggregates per reactable
  #   * Post#active_revision lookup
  #   * chat history RAG pool per user
  ADDED = {
    posts: [
      [ [ :status, :verified, :created_at ], "index_posts_on_feed_ordering" ],
      [ [ :user_id, :status, :verified ], "index_posts_on_owner_and_visibility" ]
    ],
    comments: [
      [ [ :post_id, :parent_id, :created_at ], "index_comments_on_post_and_parent_created" ]
    ],
    post_revisions: [
      [ [ :post_id, :moderation_status, :updated_at ], "index_post_revisions_on_post_and_status_updated" ]
    ],
    chat_histories: [
      [ [ :user_id, :created_at ], "index_chat_histories_on_user_and_created_at" ]
    ],
    reactions: [
      [ [ :reactable_type, :reactable_id, :emoji_type ], "index_reactions_on_reactable_and_emoji" ]
    ]
  }.freeze

  # The composite indexes below have these narrower indexes as a left prefix,
  # so keeping both only costs write throughput.
  SUPERSEDED = {
    comments: [ "index_comments_on_post_id" ],
    reactions: [ "index_reactions_on_reactable" ]
  }.freeze

  def up
    ADDED.each do |table, indexes|
      indexes.each do |columns, name|
        add_index table, columns, name: name, if_not_exists: true
      end
    end

    SUPERSEDED.each do |table, names|
      names.each { |name| remove_index table, name: name, if_exists: true }
    end
  end

  def down
    SUPERSEDED.each do |table, names|
      names.each do |name|
        columns = name == "index_comments_on_post_id" ? [ :post_id ] : [ :reactable_type, :reactable_id ]
        add_index table, columns, name: name, if_not_exists: true
      end
    end

    ADDED.each do |table, indexes|
      indexes.each { |_columns, name| remove_index table, name: name, if_exists: true }
    end
  end
end
