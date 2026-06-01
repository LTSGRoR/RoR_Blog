module Embeddings
  class Bootstrap
    class << self
      def enqueue_missing_verified_posts!(logger: Rails.logger)
        post_ids = Post.where(status: Post.statuses[:published], verified: true, embedding: nil).pluck(:id)
        return 0 if post_ids.empty?

        post_ids.each { |post_id| IndexPostEmbeddingsJob.perform_later(post_id) }
        logger.info("Embeddings::Bootstrap enqueued #{post_ids.length} posts without embeddings")
        post_ids.length
      end
    end
  end
end
