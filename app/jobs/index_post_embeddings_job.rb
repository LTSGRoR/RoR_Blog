class IndexPostEmbeddingsJob < ApplicationJob
  queue_as :default

  def perform(post_id)
    post = Post.find_by(id: post_id)
    return unless post

    service = AiGeneration::Service.new
    # build text to embed (title + excerpt)
      body_text = if post.respond_to?(:body) && post.body.present?
        if post.body.respond_to?(:to_plain_text)
          post.body.to_plain_text
        else
          post.body.to_s
        end
      else
        ""
      end

      excerpt_text = post.respond_to?(:excerpt) ? post.excerpt.to_s.presence : nil

      text = [post.title.to_s, excerpt_text || body_text.to_s.truncate(800)].compact.join("\n\n")
    embedding = service.embed(text: text)
    if embedding.present?
      post.update!(embedding: embedding)
    end
  rescue StandardError => e
    if rate_limit_error?(e) && executions < max_rate_limit_retries
      wait_seconds = rate_limit_wait_seconds
      Rails.logger.warn("IndexPostEmbeddingsJob rate limited for post_id=#{post_id}; retrying in #{wait_seconds}s (attempt #{executions + 1}/#{max_rate_limit_retries})")
      retry_job(wait: wait_seconds)
      return
    end

    Rails.logger.error("IndexPostEmbeddingsJob failed for post_id=#{post_id}: #{e.class} - #{e.message}")
    raise
  end

  private

  def rate_limit_error?(error)
    defined?(RubyLLM::RateLimitError) && error.is_a?(RubyLLM::RateLimitError)
  end

  def max_rate_limit_retries
    ENV.fetch("AI_EMBEDDING_RATE_LIMIT_RETRIES", "6").to_i
  end

  def rate_limit_wait_seconds
    base_wait = ENV.fetch("AI_EMBEDDING_RATE_LIMIT_BASE_WAIT", "2").to_f
    jitter = rand * 0.75
    (base_wait * (2**executions) + jitter).round(2)
  end
end
