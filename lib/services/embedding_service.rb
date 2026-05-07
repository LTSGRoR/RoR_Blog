require 'ruby_llm'

# Service to generate embeddings using Ollama via RubyLLM
class EmbeddingService
  include Singleton

  def initialize
    RubyLLM.configure do |config|
      config.ollama_api_base = "#{AIServices[:ollama_base_url].to_s.sub(%r{/*$}, "")}/v1"
      config.default_embedding_model = AIServices[:embedding_model]
      config.request_timeout = AIServices[:embedding_timeout]
    end

    @cache = {}
  end

  # Generate embedding for text
  # Returns: Array of floats (vector)
  # Raises: StandardError on API errors
  def generate_embedding(text)
    raise ArgumentError, "Text is required" if text.to_s.strip.blank?

    cache_key = Digest::SHA256.hexdigest(text)
    
    # Return cached embedding if available
    return @cache[cache_key] if @cache[cache_key].present?

    begin
      Rails.logger.info("Generating embedding for text: #{text[0..50]}...")
      
      embedding = RubyLLM.embed(
        text,
        model: AIServices[:embedding_model],
        provider: :ollama,
        assume_model_exists: true
      )

      vector = embedding.vectors
      @cache[cache_key] = vector
      vector
    rescue => e
      Rails.logger.error("Embedding generation failed: #{e.message}")
      raise StandardError, "Failed to generate embedding: #{e.message}"
    end
  end

  # Batch generate embeddings for multiple texts
  # Returns: Hash { text => embedding_vector }
  def generate_embeddings_batch(texts)
    texts.each_with_object({}) do |text, result|
      result[text] = generate_embedding(text)
    rescue => e
      Rails.logger.error("Batch embedding failed for text: #{text[0..50]}... - #{e.message}")
      result[text] = nil
    end
  end

  # Clear in-memory cache
  def clear_cache
    @cache.clear
  end

  private

  def retry_with_backoff(max_retries = AIServices[:max_retries])
    retries = 0
    begin
      yield
    rescue => e
      retries += 1
      if retries < max_retries
        wait_time = AIServices[:retry_delay] * (2 ** (retries - 1)) # exponential backoff
        Rails.logger.warn("Retry #{retries}/#{max_retries} after #{wait_time}s due to: #{e.message}")
        sleep(wait_time)
        retry
      else
        raise
      end
    end
  end
end
