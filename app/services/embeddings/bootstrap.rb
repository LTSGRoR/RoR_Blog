module Embeddings
  class Bootstrap
    class << self
      def enqueue_missing_verified_posts!(logger: Rails.logger)
        count = 0
        Post.where(status: Post.statuses[:published], verified: true, embedding: nil)
          .in_batches(of: 500) do |batch|
            batch.pluck(:id).each do |post_id|
              IndexPostEmbeddingsJob.perform_later(post_id)
              count += 1
            end
          end
        logger.info("Embeddings::Bootstrap enqueued #{count} posts without embeddings") if count.positive?
        count
      end
    end
  end
end
