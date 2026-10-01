class PostSearchIndexJob < ApplicationJob
  queue_as :searchkick

  def perform(post_id)
    post = Post.find_by(id: post_id)
    if post
      post.reindex
    else
      # A missing row still needs a tombstone operation in Elasticsearch.
      Post.search_index.remove(Post.new(id: post_id))
    end
  end
end
