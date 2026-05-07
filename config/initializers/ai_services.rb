# Configuration for AI/LLM services
# All settings can be overridden via environment variables

module AIServices
  CONFIG = {
    # Ollama settings
    ollama_base_url: ENV.fetch('OLLAMA_BASE_URL', 'http://localhost:11434'),
    
    # Embedding model
    embedding_model: ENV.fetch('AI_EMBEDDING_MODEL', 'nomic-embed-text'),
    embedding_dimension: ENV.fetch('AI_EMBEDDING_DIMENSION', '768').to_i,
    
    # LLM model for feedback suggestions
    llm_model: ENV.fetch('AI_LLM_MODEL', 'gemma:4b'),
    
    # Feature flags
    embeddings_enabled: ENV.fetch('AI_EMBEDDINGS_ENABLED', 'true') == 'true',
    suggestions_enabled: ENV.fetch('AI_SUGGESTIONS_ENABLED', 'true') == 'true',
    
    # Cache settings
    cache_ttl: ENV.fetch('AI_CACHE_TTL', '86400').to_i, # 24 hours
    
    # Rate limiting
    rate_limit_per_minute: ENV.fetch('AI_RATE_LIMIT_PER_MINUTE', '10').to_i,
    
    # Retry settings
    max_retries: ENV.fetch('AI_MAX_RETRIES', '3').to_i,
    retry_delay: ENV.fetch('AI_RETRY_DELAY', '2').to_i, # seconds
    
    # Timeout settings
    embedding_timeout: ENV.fetch('AI_EMBEDDING_TIMEOUT', '30').to_i, # seconds
    suggestion_timeout: ENV.fetch('AI_SUGGESTION_TIMEOUT', '60').to_i, # seconds
  }.freeze

  def self.config
    CONFIG
  end

  def self.[](key)
    CONFIG[key]
  end
end
