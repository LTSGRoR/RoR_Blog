class PostSearchIndexJob < ApplicationJob
  queue_as :searchkick

  def perform(post_id)
    post = Post.find_by(id: post_id)
    return unless post

    post.reindex
  end
end
